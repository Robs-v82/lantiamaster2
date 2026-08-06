# Análisis del Problema: Reporte de Prospectiva con 0 Destinatarios

## Contexto
- **Fecha**: Julio 16, 2026
- **Reportes enviados**: Riesgo Social (✓) y Prospectiva (✗)
- **Problema**: El reporte de Prospectiva muestra recipients_count = 0 en la vista
- **Síntoma**: "El reporte de Prospectiva fue enviado a cero destinatarios"

---

## Flujo de Envío de Reportes

```
1. Admin carga PDF en admin/reportes
   └─> AdminReportsController#upload
       ├─ Valida PDF
       └─ Crea Briefing (draft, sin envío)

2. Admin revisa y aprueba
   └─> AdminReportsController#approve
       ├─ Llama a calculate_recipients() para obtener count
       ├─ Marca pending_dispatch_jobs = 1
       └─ Inicia ReportDispatchJob.perform_later()

3. Job ejecuta en background
   └─> ReportDispatchJob#perform
       ├─ Obtiene usuarios: fetch_active_users()
       │  └─> Ejecuta query con conditions:
       │      • WHERE membership_type = 4
       │      • JOIN subscriptions
       │      • WHERE subscriptions.status = "active"
       │      • WHERE current_period_end > now_mx  ← AQUÍ EL PROBLEMA
       │
       ├─ Itera sobre usuarios enviando reportes
       ├─ Incrementa successful_count por cada envío
       └─ Actualiza Briefing con recipients_count = successful_count

4. Vista muestra recipients_count del Briefing
```

---

## El Problema Específico

### En AdminReportsController#calculate_recipients (línea 79-94):
```ruby
def calculate_recipients
  recipients_emails = fetch_active_user_emails
  count = recipients_emails.length
  render json: { recipients_count: count, recipients_emails: recipients_emails }
end

# Usa esta query en línea 203-211:
User.where(membership_type: 4)
  .joins(:subscriptions)
  .where(subscriptions: { status: "active" })
  .where("subscriptions.current_period_end > ?", Access::MembershipGate.now_mx)
  .distinct
  .pluck(:mail)
  .sort
```

### Cuando se ejecutó para Prospectiva:
- La query `fetch_active_users` retornó **0 usuarios**
- Esto significa que ningún usuario cumplía los criterios:
  - membership_type = 4 ✓ (probablemente OK)
  - status = "active" ✓ (probablemente OK)
  - **current_period_end > now_mx** ✗ ← Ninguno cumplía esto

### Por qué falló para Prospectiva pero no para Riesgo Social:

**Hipótesis 1: Problema de Zona Horaria**
- `current_period_end` se guarda como `datetime` SIN timezone
- `now_mx` se obtiene como: `Time.use_zone(TZ) { Time.zone.now }` donde TZ = "America/Mexico_City"
- PostgreSQL interpreta ambas SIN zona horaria
- Esto puede causar comparaciones incorrectas en ciertos momentos del día

**Hipótesis 2: Cambio de Subscripciones Entre Envíos**
- El Briefing de Riesgo fue enviado cuando algunos usuarios tenían suscripción activa
- Antes de enviar el de Prospectiva, todas las suscripciones expiraron
- Esto es posible si se programan cambios de suscripción o si hay un bug en la renovación

**Hipótesis 3: Bug en Cascada de Estatus**
- Cuando se marcó una suscripción como "expired", cambió el status de "active" a otro valor
- Esto afectó cómo se calcula la query para Prospectiva

---

## Evidencia en el Código

### 1. Problema de Timezone en Comparación:

**Cómo se guarda current_period_end (users_controller.rb:25, 87):**
```ruby
Subscription.create!(
  user: user,
  plan_id: 4,
  current_period_end: d.end_of_day,  # ← end_of_day retorna datetime en servidor tz
  status: 'active'
)
```

**Cómo se define en schema.rb:**
```ruby
t.datetime :current_period_end, null: false  # ← SIN timezone en la columna
```

**Cómo se compara (admin_reports_controller.rb:207):**
```ruby
.where("subscriptions.current_period_end > ?", Access::MembershipGate.now_mx)
# now_mx = Time.use_zone("America/Mexico_City") { Time.zone.now }
```

### 2. Access::MembershipGate (app/services/access/membership_gate.rb):
```ruby
class Access::MembershipGate
  TZ = "America/Mexico_City"

  def self.now_mx
    Time.use_zone(TZ) { Time.zone.now }  # ← Zona horaria explícita
  end

  def self.active_subscription(user)
    Subscription.includes(:plan)
      .where(user_id: user.id, status: "active")
      .where("current_period_end > ?", now_mx)  # ← Compara con zona
      .order(current_period_end: :desc)
      .first
  end
end
```

---

## El Bug: Raíz del Problema

1. **En producción**, `current_period_end` está almacenado como datetime sin zona
2. **Comparación inconsistente**: Mezcla timezone-aware (now_mx) con timezone-naive (current_period_end)
3. **PostgreSQL interpreta ambas como UTC** (sin timezone info)
4. **En ciertas horas del día**, la comparación devuelve resultados inesperados

### Ejemplo de fallo:
```
Supongamos:
- Suscripción expira: 2026-07-31 23:59:59 (guardada sin tz)
- now_mx cuando se ejecuta reporte: 2026-07-31 23:00:00 CST (UTC-6)
- now_mx en UTC: 2026-08-01 05:00:00 UTC

PostgreSQL compara:
  2026-07-31 23:59:59 (interpretado como UTC)
  >
  2026-08-01 05:00:00 (now_mx convertido)

Resultado: FALSE (cuando debería ser TRUE)
```

---

## Solución Propuesta

### Opción A: Usar UTC en todas partes (Recomendada)
1. Cambiar `current_period_end` a `timestamp with time zone`
2. Guardar siempre en UTC: `current_period_end: Time.current.end_of_day.in_time_zone('UTC')`
3. Comparar siempre en UTC: `.where("subscriptions.current_period_end > ?", Time.current)`

### Opción B: Usar consistentemente la zona local
1. Cambiar comparaciones para usar `now_mx` en todas partes
2. Asegurar que `current_period_end` se guarde siempre en la misma zona

---

## Próximos Pasos

1. **Verificar en Producción** (via SSH):
   - Ver registros exactos de Briefing para Riesgo y Prospectiva
   - Comparar `recipients_count` de ambos
   - Ver `delivered_emails` para entender qué sucedió

2. **Revisar Logs**:
   - Buscar messages sobre ReportDispatchJob
   - Ver cuántos usuarios se encontraron en cada caso

3. **Aplicar Fix**:
   - Crear migración para cambiar tipo de dato
   - Actualizar métodos de guardado
   - Actualizar métodos de comparación

4. **Pruebas**:
   - Resend del reporte de Prospectiva
   - Verificar que ahora tenga recipients_count correcto
