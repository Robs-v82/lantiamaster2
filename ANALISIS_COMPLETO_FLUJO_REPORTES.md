# ANÁLISIS COMPLETO DEL FLUJO DE CARGA Y ENVÍO DE REPORTES

## RESUMEN EJECUTIVO

El sistema de reportes tiene **DOS vías de almacenamiento**:
1. **Monthly Reports** (reporte_riesgo, reporte_prospectiva, reporte_conflictividad): Se adjuntan a la tabla `months`
2. **Weekly Briefings** (briefing_semanal): Se guardan en la tabla `briefings`

Ambos crean un registro en `briefings` como "borrador", pero solo los monthly reports se asocian con la tabla `months`.

---

## FLUJO COMPLETO (Paso a Paso)

### PASO 1: UPLOAD (AdminReportsController#upload)
**Archivos**: app/controllers/admin_reports_controller.rb línea 10-67

**Qué se guarda en BD:**
```ruby
# Línea 25-31
briefing = create_briefing_from_params(report_type)  # Crea Briefing en BD
briefing.pdf.attach(...)                              # Adjunta PDF (Active Storage blob)
briefing.save!                                        # GUARDA BRIEFING en tabla briefings

result = ReportSummarizerService.new(briefing.pdf.download).call
if result.ok?
  briefing.update(summary: result.summary)            # Actualiza con resumen
  session[:draft_briefing_id] = briefing.id           # Guarda en sesión
end
```

**Tabla modificada:**
- `briefings` - Se crea 1 registro con:
  - report_type: (reporte_riesgo, reporte_prospectiva, etc.)
  - month_number: 7
  - year: 2026
  - summary: (texto generado)
  - pdf: (blob adjunto)
  - sent_at: NULL (aún no enviado)
  - sent_by: NULL
  - recipients_count: NULL
  - test_mode: NULL
  - pending_dispatch_jobs: NULL

---

### PASO 2: APPROVE (AdminReportsController#approve)
**Archivo**: app/controllers/admin_reports_controller.rb línea 96-150

**Qué se guarda en BD:**
```ruby
# Línea 106-112
briefing = Briefing.find(briefing_id)  # Obtiene del Briefing creado en upload
briefing.update(summary: final_summary, test_mode: test_mode)

# PASO CRÍTICO - Línea 115-117
if briefing.monthly_report? && !test_mode
  briefing.associate_with_month  # <-- AQUÍ se adjunta a Month
end

# Línea 131-132
briefing.update(pending_dispatch_jobs: 1)
ReportDispatchJob.perform_later(briefing.id, user.mail)  # Inicia job asincrónico
```

**¿Qué es `monthly_report?`? (Briefing model, línea 61-63)**
```ruby
def monthly_report?
  %w[reporte_riesgo reporte_conflictividad reporte_prospectiva].include?(report_type)
end
```

**¿Qué es `associate_with_month`? (Briefing model, línea 78-94)**
```ruby
def associate_with_month
  return unless monthly_report?
  
  field = attachment_field_for_month  # Retorna:
                                      # reporte_riesgo -> :social_report
                                      # reporte_conflictividad -> :violence_report
                                      # reporte_prospectiva -> :forecast_report
  return unless field
  
  month = find_or_create_month  # Busca o crea Month para julio 2026
  return unless month
  
  if pdf.present?
    month.public_send("#{field}=", pdf.blob)  # Asigna PDF al campo
    month.save!                                 # GUARDA Month en BD
  end
end
```

**Tablas modificadas:**
- `briefings`:
  - summary: actualizado
  - test_mode: actualizado (true/false)
  - pending_dispatch_jobs: 1
  
- `months` (SI es monthly_report y NO es test_mode):
  - Si no existe Month para julio 2026, se CREA
  - Se adjunta PDF al campo correspondiente:
    - social_report (reporte_riesgo)
    - violence_report (reporte_conflictividad)
    - forecast_report (reporte_prospectiva)

**Validaciones importantes:**
- Briefing.uniqueness validation (línea 18-21 del modelo):
  ```ruby
  validates :report_type,
            uniqueness: { scope: [:month_number, :year],
                          message: "ya existe un reporte de este tipo para ese mes/año" },
            if: proc { |b| b.report_type != 'briefing_semanal' }
  ```
  
  **ESTO SIGNIFICA**: No puede haber dos Briefing con:
  - MISMO report_type (ej: reporte_prospectiva)
  - MISMO month_number (7)
  - MISMO year (2026)

---

### PASO 3: DISPATCH (ReportDispatchJob#perform)
**Archivo**: app/jobs/report_dispatch_job.rb línea 1-56

**Qué sucede:**
```ruby
def perform(briefing_id, sent_by_email)
  briefing = Briefing.find(briefing_id)
  return if briefing.sent_at.present?  # Si ya fue enviado, retorna
  
  users = fetch_active_users  # Obtiene usuarios con subscripciones activas
  
  users.each do |user|
    begin
      ReportMailer.dispatch(user, briefing).deliver_now
      briefing.mark_email_delivered!(user.mail)
      successful_count += 1
    rescue => e
      # Error SMTP o similar - no incrementa successful_count
    end
  end
  
  # ACTUALIZACIÓN FINAL
  briefing.update!(
    sent_at: Time.current,
    sent_by: sent_by_email,
    recipients_count: successful_count  # <-- AQUÍ SE GUARDA 0 si todos fallaron
  )
end
```

**Tablas modificadas:**
- `briefings`:
  - sent_at: Time.current (marca como enviado)
  - sent_by: email del usuario
  - recipients_count: cantidad de emails enviados exitosamente
  - delivered_emails: JSON array con emails entregados

---

## CÓMO APARECEN EN LA VISTA DOWNLOADS

**Archivo**: app/views/datasets/downloads.html.erb y app/controllers/datasets_controller.rb línea 2682-2703

### Para Monthly Reports (reporte_riesgo, prospectiva, etc.)
```ruby
# Línea 2683-2685 del controlador
@v_months = Month.with_violence_report.sort { |a, b| b <=> a }
@s_months = Month.with_social_report.sort { |a, b| b <=> a }
@f_months = Month.with_forecast_report.sort { |a, b| b <=> a }
```

**Estos scopes buscan meses QUE TIENEN un PDF adjunto.**

**En la vista** (línea 29-46, 59-76, 89-106):
```erb
<% @v_months.each_with_index do |month, index| %>
  <a href="<%= rails_blob_path(month.violence_report, disposition: "attachment") %>">
    <!-- DESCARGA EL PDF -->
  </a>
<% end %>
```

### Para Weekly Briefings
```ruby
# Línea 2699-2702 del controlador
@briefings_new = Briefing.where(report_type: "briefing_semanal")
  .where.not(sent_at: nil)        # SOLO briefings que ya fueron enviados
  .where(test_mode: false)        # SOLO en modo producción
  .order(year: :desc, month_number: :desc, id: :desc)
```

---

## PROBLEMA DEL 31 DE JULIO

### Lo que pasó:

1. **Briefing 57 (reporte_prospectiva) fue aprobado DUAS VECES**
   - Primera aprobación: Se creó/actualizó Month para julio 2026 con forecast_report
   - Segunda aprobación: Se intentó de nuevo, pero la validación de uniqueness debería haberlo impedido
   - RESULTADO: Ambas ejecuciones de ReportDispatchJob enviaron a los mismos usuarios, saturando SMTP

2. **Briefing 58 (reporte_prospectiva)**
   - Se aprobó después que Briefing 57 ya tenía una aprobación
   - Falló la validación de uniqueness? No, porque ya hay un Briefing 57
   - **ESPERA**: Si Briefing 57 ya existe con reporte_prospectiva para julio 2026...
   - ¿Cómo se permitió crear Briefing 58 también con reporte_prospectiva para julio 2026?

3. **Briefing 59 (reporte_conflictividad)**
   - Similar issue

### Investigación necesaria:
**¿Cómo llegaron a existir AMBOS Briefing 58 Y 59 si hay validación de uniqueness?**

Posibles respuestas:
- La validación se aplica solo en CREATE, no en UPDATE
- Hubo un race condition entre upload y approve
- El report_type se guardó diferente

---

## COMANDOS RAILS PARA LIMPIAR LA BD

**ANTES DE EJECUTAR CUALQUIER COMANDO, REVISAR:**

```ruby
# En consola Rails
Briefing.where(month_number: 7, year: 2026).pluck(:id, :report_type, :sent_at, :recipients_count)
Month.where(name: "2026_07").first&.attributes
```

**LIMPIEZA SEGURA:**

1. **Borrar Briefing 58 y 59:**
```ruby
Briefing.where(id: [58, 59]).destroy_all
# O si necesita confirmación:
Briefing.find(58).destroy
Briefing.find(59).destroy
```

2. **Verificar Month de julio 2026:**
```ruby
month = Month.find_by(name: "2026_07")
month.social_report.present?      # Debe ser true (reporte riesgo)
month.violence_report.present?    # Verificar si tiene reporte conflictividad
month.forecast_report.present?    # Debe ser true (prospectiva)
```

3. **Actualizar Briefing 57 si es necesario:**
```ruby
briefing57 = Briefing.find(57)
briefing57.recipients_count  # Ver cuántos usuarios realmente recibieron
```

---

## RESUMEN DE TABLAS AFECTADAS

| Tabla | Operación | Cuándo |
|-------|-----------|--------|
| briefings | CREATE | Upload |
| active_storage_blobs | CREATE | Upload (PDF) |
| active_storage_attachments | CREATE | Upload (adjunta PDF) |
| briefings | UPDATE | Approve (summary, test_mode, pending_dispatch_jobs) |
| months | CREATE/UPDATE | Approve (si es monthly_report) |
| active_storage_attachments | CREATE | Approve (adjunta PDF a Month) |
| briefings | UPDATE | Dispatch (sent_at, sent_by, recipients_count, delivered_emails) |

