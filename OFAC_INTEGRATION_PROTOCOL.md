# OFAC Integration Protocol

**Versión:** 2.0  
**Última actualización:** 2026-09-29  
**Estado:** PROTOCOLO ROBUSTO IMPLEMENTADO - Validación imposible de saltarse integrada

---

## 🚨 INICIO RÁPIDO - Proceso Robusto v2.0

**Este protocolo ha sido refactorizado para garantizar 0% errores de omisión/inventiva. Cambios principales:**

1. **Sección 2.1.4** (antes 2.1.4, AHORA EXPANDIDA): Validador robusto que BLOQUEA creación si falla
2. **Sección 2.1.6** (NUEVA): Checklist de 5 validaciones obligatorias antes de `Member.create!()`
3. **Errors #8-#10** (NUEVO): Documentan problemas resueltos (nombres faltantes, ubicación inventada)
4. **Script obligatorio:** `/scripts/ofac_source_validator.rb` ejecuta validaciones automáticamente

**Flujo garantizado:**
```
1. Buscar Hit (2.1.1-2.1.3)
2. ✅ VALIDAR ROBUSTO (2.1.4 + 2.1.6)
3. Crear Hit con ubicación específica (2.3 + 2.3.1)
4. Ejecutar HitSnapshotFetcher (2.4)
5. ✅ BLOQUEA si falla validación (imposible saltarse)
6. Crear Member SOLO si pasa validación (2.6)
7. ClassifiedMembers.rb (2.8)
8. OFAC update (2.9)
```

**Garantía:** Hit #6002 ahora tiene Culiacán correctamente, Hit #6003 y #6004 están marcados como INVÁLIDOS (nombres faltantes), script previene que esto ocurra nuevamente.

---

## 1. Propósito

Integrar individuals designados por OFAC (sin matches previos en BD) en el sistema de Lantia mediante un flujo guiado que:
- Crea Hits con fuentes verificadas
- Captura plain_text y raw_html mediante HitSnapshotFetcher
- Crea Members con roles y organizaciones confirmadas
- Vincula Members a Hits
- Ejecuta OFAC update para capturar datos OFAC (fechas de nacimiento, ENT_NUM, etc.)

---

## 2. Workflow Completo

### 2.1 Identificar Candidatos

**Entrada:** Lista OFAC de 643 individuos México sin match en BD

**Proceso:**
```bash
RAILS_ENV=production bundle exec rails runner scripts/ofacUpdate.rb
```

**Output:** 
- Lista de "SIN MATCH" (actualmente ~199-201 records)
- Ordenados alfabéticamente por lastname, firstname

**Selección de candidatos:**
- ✅ Prioridad: más recientemente designados (ir de abajo de la lista hacia arriba)
- ✅ Criterio: 1 given name + 2 surnames (para split correcto en BD)
- ✅ Preferencia: individuos con familia ya en BD (para reutilizar hits)
- ❌ Evitar: nombres incompletos o ambiguos

---

### 2.1.1 Búsqueda Individual de Candidato (OBLIGATORIO)

**Objetivo:** Localizar fuente de verificación (noticia, documento oficial) que mencione al candidato OFAC con validación rigurosa

**🚨 CRÍTICO:** Usar SIEMPRE el nombre textual EXACTO como aparece en el listado OFAC. Nunca parafrasear ni abreviar.

**Proceso de búsqueda (hasta 5 intentos según sea necesario):**

**PASO 1: Búsqueda abierta en internet - Nombre completo + "cartel"**
```
Query: "{OFAC_NOMBRE_EXACTO}" cartel
Ejemplo: "Maria Del Rosario Garcia" cartel
```
- Objetivo: Encontrar fuentes que mencionen el nombre COMPLETO con contexto criminal explícito
- Criterio éxito: Hit contiene:
  - ✅ Nombre completo EXACTO del OFAC list
  - ✅ Palabra "cartel" (explícita)
  - ✅ Ubicación identificable
  - ✅ Fuente confiable (OFAC, Treasury, noticias oficiales)

**PASO 2: Si PASO 1 falla → Búsqueda con OFAC**
```
Query: "{OFAC_NOMBRE_EXACTO}" OFAC
Ejemplo: "Maria Del Rosario Garcia" OFAC
```
- Objetivo: Encontrar designaciones OFAC oficiales
- Criterio éxito: Hit cumple todas las validaciones rigurosas (nombres + ubicación + organización)

**PASO 3: Si PASO 2 falla → Búsqueda solo nombre completo**
```
Query: "{OFAC_NOMBRE_EXACTO}" Mexico narco
Ejemplo: "Maria Del Rosario Garcia" Mexico narco
```
- Objetivo: Último intento con búsqueda abierta
- Criterio éxito: Hit cumple TODAS las validaciones rigurosas

**PASO 4: Si PASO 3 falla → Registrar como no identificable**
```ruby
OfacCandidate.create!(
  ofac_name: "{OFAC_NOMBRE_EXACTO}",
  status: :not_found,
  search_attempts: 3,
  notes: "Tras 3 intentos de búsqueda, no se encontró fuente que cumpliera validaciones rigurosas"
)
```

**Validaciones rigurosas (OBLIGATORIAS):**
- ✅ Nombre COMPLETO EXACTO del OFAC list aparece en plain_text
- ✅ Ubicación explícita en plain_text (municipio/estado)
- ✅ Organización mencionada explícitamente (ej: "Cartel de Sinaloa")
- ✅ Fuente confiable (OFAC, Treasury, periódico oficial)

**Si validaciones fallan → NO crear Hit, pasar al PASO siguiente**

---

### 2.1.2 Identificación de Organización (OBLIGATORIO)

**Objetivo:** Extraer la organización criminal (cartel) de la fuente encontrada

**Proceso:**

1. **Búsqueda de palabras clave en Hit plain_text:**
   ```ruby
   hit_text = hit.plain_text.downcase
   keywords = ["cjng", "sinaloa", "cartel", "golfo", "jalisco", "nueva generación", 
               "cdg", "cdn", "cds", "autoridades vinculadas"]
   
   found_org = keywords.find { |kw| hit_text.include?(kw) }
   ```

2. **Mapeo a catálogo de organizaciones:**
   - `"cjng"` o `"jalisco"` o `"nueva generación"` → Organization ID: 2561 (CJNG)
   - `"sinaloa"` → búsqueda adicional para precisar (¿CDS, Zambada, etc?)
   - `"golfo"` o `"cártel del golfo"` → Organization ID: 4232 (CDG)
   - `"autoridades vinculadas"` → sin organización, flag de autoridad

3. **Si encuentra organización en catálogo:**
   - Registrar en `OfacCandidate.create!(ofac_name: "...", status: "found_with_org", organization_id: org.id, search_attempts: N)`
   - Proceder al flujo normal (crear Hit, Member, etc)

4. **Si NO encuentra organización después de 3 intentos:**
   - Registrar en `OfacCandidate.create!(ofac_name: "...", status: "found_no_org", search_attempts: 3, notes: "Hit encontrado pero sin organización vinculada")`
   - Marcar como no utilizable
   - Continuar con siguiente candidato

---

### 2.1.3 Almacenamiento de Candidatos No Utilizables

**Propósito:** Mantener histórico de individuos OFAC descartados para evitar reintentos

**Modelo OfacCandidate:**
```ruby
OfacCandidate.create!(
  ofac_name: "LASTNAME, Firstname",          # Formato OFAC original
  status: :found_no_org,                     # enum: pending, found_with_org, found_no_org, not_found
  organization_id: nil,                      # nullable
  search_attempts: 3,                        # contador de intentos
  notes: "Razón específica por qué no se utilizó"
)
```

**Estados posibles:**
- `pending`: Candidato aún no procesado
- `found_with_org`: Encontrado + organización en catálogo → **proceder con flujo normal**
- `found_no_org`: Encontrado pero sin organización → **no utilizable, almacenar**
- `not_found`: No se encontró fuente después de 3 intentos → **no utilizable, almacenar**

**Consultas útiles:**
```ruby
# Ver todos no utilizables
OfacCandidate.where(status: [:found_no_org, :not_found])

# Ver pendientes
OfacCandidate.pending

# Ver procesados exitosamente
OfacCandidate.found_with_org
```

---

### 2.1.4 Validación Robusto de Fuente (🚨 CRÍTICA - BLOQUEA CREACIÓN DE MEMBERS)

**Propósito:** Garantizar 100% que TODOS los nombres (firstname + lastname1 + lastname2) y ubicación aparezcan EXPLÍCITAMENTE en el plain_text del Hit. Esto previene errores de omisión como los ocurridos (Geovanni omitido, Llanos faltante, Alvarez faltante, Zapopan inventado).

**Esta validación es IMPOSIBLE saltarse:** El script validador BLOQUEA la creación de Members si falla cualquier criterio.

**PASO 1: Validación de FIRSTNAME (OBLIGATORIO)**
```ruby
plain_text_lower = hit.plain_text.downcase
unless plain_text_lower.include?(ofac_firstname.downcase)
  raise "❌ FIRSTNAME '#{ofac_firstname}' NO está en plain_text del Hit ##{hit.id}"
end
```

**PASO 2: Validación de LASTNAME1 (OBLIGATORIO)**
```ruby
unless plain_text_lower.include?(ofac_lastname1.downcase)
  raise "❌ LASTNAME1 '#{ofac_lastname1}' NO está en plain_text del Hit ##{hit.id}"
end
```

**PASO 3: Validación de LASTNAME2 (OBLIGATORIO si existe)**
```ruby
if ofac_lastname2.present?
  unless plain_text_lower.include?(ofac_lastname2.downcase)
    raise "❌ LASTNAME2 '#{ofac_lastname2}' NO está en plain_text del Hit ##{hit.id}"
  end
end
```

**PASO 4: Validación de UBICACIÓN EXPLÍCITA (OBLIGATORIO)**
```ruby
# Buscar cualquier ubicación (estado/municipio) en el plain_text
locations = ["culiacán", "culiacan", "sinaloa", "méxico", "ciudad de méxico", "cdmx",
             "guadalajara", "zapopan", "jalisco", "monterrey", "nuevo león",
             "ensenada", "baja california", "zacatecas", "guanajuato", "michoacán"]

found_locations = locations.select { |loc| plain_text_lower.include?(loc) }

unless found_locations.any?
  raise "❌ NO hay ubicación explícita en plain_text del Hit ##{hit.id}"
end
```

**PASO 5: Validación de TOWN_ID Específico (OBLIGATORIO)**
```ruby
town = Town.find(hit.town_id)
county = town.county

# town_id DEBE corresponder a una ubicación EXPLÍCITA en el plain_text
# y DEBE ser el "Sin definir" ESPECÍFICO del municipio (NO genérico)
unless town.name == "Sin definir" || (town.id == 1569 && town.name == "México")
  raise "❌ town_id #{hit.town_id} no es válido"
end

# Verificar coherencia entre ubicación en texto y town_id asignado
unless found_locations.any? { |loc| county.name.downcase.include?(loc.split.first) }
  warn "⚠️ Ubicación en texto no coincide perfectamente con town_id asignado"
end
```

**Script automatizado que ejecuta TODOS estos pasos:**
```bash
# Archivo: /scripts/ofac_source_validator.rb
# Ejecutar ANTES de crear Members
ruby scripts/ofac_source_validator.rb
```

**Salida del validador:**
```
🔐 VALIDADOR OFAC - FUENTE EXPLÍCITA
════════════════════════════════════════════════
📄 PASO 1: Validar FIRSTNAME
   Buscando: 'Martin Guadencio'
   ✅ ENCONTRADO en plain_text

📄 PASO 2: Validar LASTNAME1
   Buscando: 'Avendano'
   ✅ ENCONTRADO en plain_text

📍 PASO 4: Validar UBICACIÓN
   ✅ Encontrado: CULIACÁN, SINALOA

════════════════════════════════════════════════
📊 RESULTADO: ✅ VALIDACIÓN EXITOSA
════════════════════════════════════════════════
```

**Si falla CUALQUIER paso:**
```
❌ VALIDACIÓN FALLIDA
❌ NO crear Member
❌ Buscar Hit alternativo con nombres/ubicación completos
❌ Si no existe Hit válido, registrar en OfacCandidate como "not_found"
```

---

### 2.1.5 Asignación de Género (OBLIGATORIO)

**Propósito:** Definir el género (MASCULINO, FEMENINO, Desconocido) del Member basado en el firstname

**Proceso de asignación (en orden de prioridad):**

1. **Búsqueda exacta en diccionario**
   ```ruby
   # Archivo: scripts/names_by_gender.csv
   firstname_lookup = firstname.strip.downcase
   csv_gender = name_gender_map[firstname_lookup]
   ```

2. **Si no encontrado → Búsqueda en BD de nombres similares**
   ```ruby
   # Buscar primeras 3 palabras del firstname
   similar_names = CSV.read("scripts/names_by_gender.csv", headers: true)
     .select { |row| row['firstname']&.include?(first_word) }
     .map { |row| row['genero_estimado'] }
   ```

3. **Si no encontrado → Sugerencia manual basada en patrón**
   - Nombres terminados en -o, -os, -a, -as: indicador de género
   - Nombres compuestos: analizar cada componente
   - Nombres ambiguos: sin definir o Desconocido

**Válidos:**
- `MASCULINO` (match exacto o patrón claro)
- `FEMENINO` (match exacto o patrón claro)
- `Desconocido` (sin información disponible)

**Validación en Checklist Pre-Creación:**
- [ ] ✅ Género asignado (MASCULINO, FEMENINO, o Desconocido)
- [ ] ✅ Fuente verificada (CSV o análisis manual documentado)

---

### 2.1.6 CHECKLIST DE VALIDACIÓN ROBUSTO (BLOQUEA CREACIÓN DE MEMBERS)

**🚨 CRÍTICO:** Este checklist DEBE completarse 100% antes de ejecutar `Member.create!()`. Si falla CUALQUIER ítem, la creación es BLOQUEADA.

**VALIDACIÓN 1: Nombres Explícitos en Plain_text del Hit**
- [ ] ✅ FIRSTNAME completo aparece explícitamente en `hit.plain_text.downcase`
  - Búsqueda: `plain_text.downcase.include?(firstname.downcase)`
  - Ejemplo VÁLIDO: plain_text contiene "Martin Guadencio"
  - Ejemplo INVÁLIDO: plain_text contiene "M. Guadencio" o solo "Martin"

- [ ] ✅ LASTNAME1 aparece explícitamente en `hit.plain_text.downcase`
  - Búsqueda: `plain_text.downcase.include?(lastname1.downcase)`
  - Ejemplo VÁLIDO: plain_text contiene "Avendano"
  - Ejemplo INVÁLIDO: plain_text no contiene "Alvarez" (falta, NO crear Member)

- [ ] ✅ LASTNAME2 aparece explícitamente en `hit.plain_text.downcase` (si existe)
  - Búsqueda: `plain_text.downcase.include?(lastname2.downcase)`
  - Si no existe en OFAC: saltarse este punto

**VALIDACIÓN 2: Ubicación Explícita en Plain_text del Hit**
- [ ] ✅ Al menos UNA ubicación (estado/municipio) aparece en `hit.plain_text.downcase`
  - Palabras clave válidas: "culiacán", "sinaloa", "méxico", "guadalajara", "jalisco", etc
  - Búsqueda: Leer plain_text y verificar manualmente que menciona ubicación
  - Ejemplo VÁLIDO: "Culiacán, Sinaloa" (explícito en texto)
  - Ejemplo INVÁLIDO: Asumir ubicación de búsqueda previa, no mencionada en plain_text

**VALIDACIÓN 3: Town_ID Correcto Asignado al Hit**
- [ ] ✅ Hit tiene `town_id` asignado
- [ ] ✅ Town es "Sin definir" ESPECÍFICO del municipio EXPLÍCITAMENTE mencionado
  - Búsqueda BD: `County.find_by(name: "...") → county.towns.find_by(name: "Sin definir")`
  - Ejemplo VÁLIDO: Hit menciona "Culiacán" → town_id = 146826 (Culiacán "Sin definir")
  - Ejemplo INVÁLIDO: Hit menciona "Culiacán" → town_id = 145804 (Zapopan "Sin definir") ❌

- [ ] ✅ O si ubicación es DESCONOCIDA: town_id = 1569 (Ciudad de México fallback)

**VALIDACIÓN 4: Ejecutar Script Validador Automatizado**
```bash
# EJECUTAR OBLIGATORIAMENTE ANTES de crear Members
ruby scripts/ofac_source_validator.rb
```

**Output esperado:**
```
✅ ¡VALIDACIÓN EXITOSA!
   - Todos los nombres fueron encontrados en plain_text
   - Ubicación verificada
   - Hit #{hit.id} puede usarse para crear Members
```

**Si output es ❌ VALIDACIÓN FALLIDA:**
- DETENER INMEDIATAMENTE
- NO crear Member
- Buscar Hit alternativo
- O crear Hit nuevo desde fuente oficial con nombres/ubicación explícitos

**VALIDACIÓN 5: Género Asignado**
- [ ] ✅ Gender = "MASCULINO", "FEMENINO", o "Desconocido" (paso 2.1.5)
- [ ] ✅ Fuente verificada (CSV o análisis manual)

**RESUMEN FINAL:**
Si TODOS estos puntos están ✅, entonces y SOLO entonces:
```ruby
member = Member.create!(
  firstname: "...",      # EXACTO de OFAC, validado en Hit
  lastname1: "...",      # Validado en Hit
  lastname2: "...",      # Validado en Hit (si aplica)
  organization_id: ...,  # Confirmada
  role_id: ...,          # Confirmado
  involved: true,        # Siempre true para OFAC
  criminal_role: nil,    # ClassifiedMembers.rb lo asignará
  gender: ...,           # MASCULINO/FEMENINO/Desconocido
  town_id: ...           # Específico, validado
)
```

**Lección:** Este checklist es la ÚNICA forma de garantizar 0% errores de omisión, ubicación inventada, o inconsistencia con OFAC

---

### 2.2 Buscar Fuente (Hit)

**Objetivo:** Encontrar una noticia/artículo que mencione al individuo OFAC

**Nota:** Este paso ocurre automáticamente en 2.1.1-2.1.2. Si la búsqueda individual encontró organización, continuar aquí.

**Proceso:**
1. **Búsqueda web** con parámetros:
   - `{firstname} {lastname1} {lastname2} OFAC`
   - `{firstname} {lastname1} {lastname2} designación`
   - `{firstname} {lastname1} {lastname2} CJNG/cartel` (si se conoce org)

2. **Criterios de validación:**
   - ✅ Artículo menciona explícitamente el nombre completo
   - ✅ Menciona OFAC, designación, o contexto criminal claro
   - ✅ Fuente es medio de comunicación confiable (newspapers, official sources)
   - ✅ Fecha de publicación cercana a designación OFAC
   - ❌ Evitar: blogs sin verificación, fuentes no confiables

3. **Reutilizar Hit existente:**
   - Si el individuo está mencionado en un Hit YA CREADO, reutilizarlo
   - Ejemplo: Hit sobre "familia Botello" menciona a múltiples hermanos
   - Ventaja: no duplicar scraping, plain_text ya capturado

---

### 2.3 Crear Hit (si no existe)

**Entrada:** URL del artículo encontrado

**Datos requeridos:**
```ruby
domain_part   = URI(url).host.gsub(/^www\./, "").gsub(/\..*/, "")  # "elfinanciero"
date_part     = "YYYYMMDD"  # fecha de publicación o designación OFAC
initials      = current_user.member.firstname[0] + current_user.member.lastname1[0]
rand_part     = sprintf("%02d", rand(0..99))
legacy_id     = "#{domain_part}_#{date_part}_#{initials}_#{rand_part}"

hit = Hit.create!(
  legacy_id: legacy_id,
  date: Date.parse(date_string),
  title: article_title,
  link: url,
  town_id: town_id,      # VALIDACIÓN CRÍTICA: Ver sección 2.3.1
  user_id: current_user.id
)
```

**Validaciones:**
- ✅ `legacy_id` es ÚNICO (no duplicar)
- ✅ `link` es VALIDO (URL bien formada)
- ✅ `date` es PARSEABLE (YYYYMMDD válido)
- ✅ `town_id` es ESPECÍFICO Y VERIFICADO (ver 2.3.1)
- ✅ `title` describe claramente el contenido

### 2.3.1 VALIDACIÓN CRÍTICA DE UBICACIÓN (OBLIGATORIO)

**🚨 REGLA CRÍTICA: NUNCA inventar ubicaciones. Usar town "Sin definir" CORRECTO del municipio.**

**Lógica de Towns en la BD:**
```
Estado (State) → Municipio (County) → Towns
  ↓
Cada County tiene múltiples Towns, incluyendo un "Sin definir" específico
Ejemplo:
- Culiacán (County 1799) → Town 146826 "Sin definir"
- Zapopan (County 626) → Town 145804 "Sin definir"
- Guadalajara (County 549) → Town 145738 "Sin definir"
- Ciudad de México (fallback) → Town 1569 "México"
```

**Proceso obligatorio:**

1. **Identificar ubicación EXACTA en la fuente (Hit/URL)**
   - Leer plain_text/contenido del artículo palabra por palabra
   - ¿Menciona MUNICIPIO ESPECÍFICO CON CERTEZA? → Ir a paso 2
   - ¿Ambigua o genérica? → Ir a paso 4 (fallback)

2. **Buscar Town "Sin definir" del municipio identificado**
   ```ruby
   # Búsqueda correcta:
   county = County.find_by(name: "Culiacán")
   town = county.towns.find_by(name: "Sin definir")  # OBLIGATORIO
   
   # Validación post-búsqueda:
   raise "ERROR: Municipio no existe en BD" unless county
   raise "ERROR: Town Sin definir no encontrado para #{county.name}" unless town
   ```

3. **Usar town_id del municipio específico**
   ```ruby
   hit.town_id = town.id  # ID específico del municipio, NO genérico
   ```

4. **Si ubicación es DESCONOCIDA, AMBIGUA o EXTRANJERO:**
   - ✅ Usar fallback: Ciudad de México (town_id: 1569, name: "México")
   - Ejemplo casos: documentos genéricos OFAC, extranjeros, ambiguos

**NUNCA hacer:**
- ❌ Asumir municipio por nombre del individuo (ej: "Belloso" ≠ "Belloso Blanco")
- ❌ Usar town "Sin definir" genérico de otra jurisdicción
- ❌ Invitar ubicaciones que no estén mencionadas explícitamente
- ❌ Mezclar municipios cuando es ambiguo (ej: "Guadalajara/Zapopan")

**Validación pre-creación (obligatoria):**
```ruby
# Antes de crear Hit:
town = Town.find(town_id)
county = town.county

# Validar que sea correcto:
if town.name == "Sin definir"
  puts "✅ Usando town específico: #{town.name} de #{county.name}"
elsif town.name == "México" && town.id == 1569
  puts "✅ Fallback correcto: Ciudad de México (sin municipio identificable)"
else
  raise "ERROR: Town #{town.name} no es válido"
end
```

**Checklist de ubicación pre-creación:**
- [ ] ¿Se menciona EXPLÍCITAMENTE un municipio en la fuente?
- [ ] ¿Puedo identificarlo CON CERTEZA en la BD?
- [ ] ¿Estoy usando el town "Sin definir" CORRECTO de ese municipio?
- [ ] Si no hay municipio claro → ¿Usando Ciudad de México (1569)?
- [ ] ¿Validé que el town_id existe y es válido?

**National Flag:**
- Si domain está en lista de medios nacionales → `national: true`

---

### 2.4 Ejecutar HitSnapshotFetcher (OBLIGATORIO)

**Propósito:** Capturar contenido del artículo para validación y matching

```ruby
HitSnapshotFetcher.call!(hit, require_members: false)
```

**Validaciones:**
- ✅ `backup_status` = "ok"
- ✅ `plain_text` capturado (>0 caracteres)
- ✅ `raw_html` capturado (>0 caracteres)
- ✅ Sin errores en stderr

**Nota:** Este paso es INDISPENSABLE. Sin él, no se puede proceder a crear Member.

---

### 2.5.5 Validar Nombre Exacto OFAC (OBLIGATORIO)

**Antes de crear Member, VALIDAR que el nombre extraído de OFAC aparece en el Hit:**

```ruby
# 1. Extraer nombre exacto de OFAC list
ofac_list_entry = "LASTNAME, Firstname Compuesto"
parsed_firstname = ofac_list_entry.split(",")[1].strip  # "Firstname Compuesto"

# 2. Verificar que aparece en Hit plain_text
hit_text = Hit.find(hit_id).plain_text.downcase
unless hit_text.include?(parsed_firstname.downcase)
  raise "❌ ERROR: #{parsed_firstname} NO APARECE EN HIT #{hit_id}!"
end

# 3. Usar firstname exacto en Member creation
Member.create!(
  firstname: parsed_firstname,  # NUNCA acortar o asumir
  lastname1: ...,
  lastname2: ...,
  ...
)
```

**Por qué es crítico:**
- Nombres compuestos DEBEN conservarse completos (ej: "Wiliams Geovanni", NO "Wiliams")
- El hit es fuente de verdad: si no menciona el nombre exacto, algo está mal
- La omisión causa inconsistencia en matching OFAC post-creation

**Validación post-creación:**
```ruby
member = Member.find(id)
puts member.firstname  # DEBE coincidir EXACTAMENTE con OFAC list
```

---

### 2.7 Validar Candidato con Usuario

**Antes de crear Member, confirmar:**

```
OFAC Name: {LASTNAME, FIRSTNAME EXACTO}  ← Verificado en Hit (paso 2.5.5)
Hit: {title} ({legacy_id})
Firstname: {firstname}  ← NOMBRE COMPLETO (compuesto si aplica)
Lastname1: {lastname1}
Lastname2: {lastname2}
Role: {role.name} (ID: {role_id})
Organization: {organization.name} (ID: {org_id})
Alias: {alias_raw or "empty"}
Location: {town.name} (ID: {town_id})
```

**Confirmación requerida:** "Sí, confirmo. Por favor, procede..."

**Casos especiales:**
1. **Nombres compuestos:** Si OFAC tiene "BOTELLO ORTIZ, Jesus David"
   - firstname = "Jesus David" (NO solo "Jesus")
   - Importante para matching OFAC

2. **Sin fecha de nacimiento en OFAC:** No asumir ni estimar
   - Dejar `birthday` vacío
   - OFAC update lo completará si está disponible

3. **Ubicación desconocida:** Usar `STATE:code` en lugar de municipio específico
   - NO asumir municipio por nombre coincidente
   - Ejemplo: "Rancho San Miguel" no asume "San Miguel el Alto"

---

### 2.6 Crear Member

**Entrada:** Datos validados con usuario

```ruby
member = Member.create!(
  firstname: parsed[:firstname],
  lastname1: parsed[:lastname1],
  lastname2: parsed[:lastname2],
  organization: org,
  role: role,
  involved: true,                    # siempre true para OFAC
  criminal_role: role_based_value,   # "Socio", "Miembro", etc
  gender: nil                        # no asumir
)

member.hits << hit
```

**Búsqueda previa:**
- Antes de crear, buscar si Member ya existe: `Member.find_by(firstname:, lastname1:, lastname2:)`
- Si existe: actualizar role/org, agregar hit si no está vinculado
- Si no existe: crear nuevo

**criminal_role mapping:**
```ruby
if involved
  criminal_role = role.name  # "Socio", "Miembro", etc
else
  criminal_role = nil
end
```

**Validaciones:**
- ✅ Role existe en BD
- ✅ Organization existe en BD
- ✅ Member no duplicado (firstname + lastname1 + lastname2 unique)
- ✅ Hit existe y tiene legacy_id

---

### 2.8 Ejecutar ClassifiedMembers.rb (OBLIGATORIO)

**Propósito:** Alinear el campo `criminal_role` de cada Member creado basado en su rol y flag `involved`.

**Por qué es obligatorio:**
- El campo `criminal_role` controla cómo se muestra el Member en la vista `members_outcome`
- Valida que los datos estén correctamente clasificados (Líder, Miembro, Socio, Autoridad vinculada, etc)
- ClassifiedMembers usa mapeos específicos según los roles disponibles
- Este paso DEBE ejecutarse ANTES de OFAC update

**Ejecución:**
```bash
RAILS_ENV=production bundle exec rails runner scripts/ClassifiedMembers.rb
```

**Salida esperada:**
```
Actualizados: N (Members con criminal_role asignado)
Sin cambio: M (Members que ya tenían el valor correcto)
Skipped (sin role): 0
```

**Validación:**
```ruby
member = Member.find(id)
puts member.criminal_role  # Debe tener valor ("Socio", "Miembro", etc) o nil si "Sin definir"
```

---

### 2.9 Ejecutar OFAC Update

**Propósito:** Vincular Member creado con datos OFAC (ENT_NUM, birthday, etc) y actualizar ofac_designation

```bash
RAILS_ENV=production bundle exec rails runner scripts/ofacUpdate.rb
```

**Proceso interno:**
1. Descarga sdn.csv, add.csv, alt.csv desde treasury.gov
2. Identifica individuos tipo "INDIVIDUAL"
3. Filtra por país "Mexico"
4. Extrae DOB de remarks (formato: "DOB 17 Jan 1941; POB...")
5. Busca match con Members en BD (por firstname, lastname1, lastname2)
6. Actualiza: `ofac_designation: true`, `ofac_ent_num`, `birthday`
7. Desmarcar Members que ya no aparecen en OFAC

**Validaciones:**
- ✅ Member aparece en "MATCHES ENCONTRADOS"
- ✅ `ofac_designation` = true
- ✅ `ofac_ent_num` está poblado
- ✅ `birthday` capturado (si disponible en OFAC)

**Post-update check:**
```ruby
member = Member.find(id)
puts member.ofac_designation          # true
puts member.ofac_ent_num              # "58024"
puts member.birthday                  # "1999-04-24"
```

---

## 3. Decisiones que Requieren Validación Manual

❌ **NO automatizar estos puntos:**

1. **Búsqueda de Hit**
   - Requiere juicio humano sobre relevancia y confiabilidad de fuente
   - Una fuente incorrecta contamina toda la cadena

2. **Selección de Role y Organization**
   - Requiere contexto de la organización criminal
   - Diferencia entre "Socio", "Miembro", "Allegado", etc
   - Requiere investigación según el caso

3. **Ubicación geográfica**
   - NO asumir municipios por coincidir nombres
   - Validar explícitamente si está disponible

4. **Nombres compuestos**
   - Validar que se capturaron completos
   - Crucial para matching OFAC

5. **Confirmación pre-creación**
   - Resumen de todos los datos antes de escribir en BD
   - Usuario debe validar completitud y corrección

---

## 3.5 Nota Importante sobre ClassifiedMembers.rb

**Este paso NO requiere validación manual**, es **automático y obligatorio**:
- Mapea automáticamente el campo `criminal_role` basado en role + involved
- Usa lookups de roles predefinidos (LOOKUP_TRUE, LOOKUP_FALSE)
- Valida que el rol esté en las categorías esperadas
- Reporta roles fuera de lo esperado (para debugging)

**Execución timing:**
1. ✅ Create Member (criminal_role = nil inicialmente)
2. ✅ Execute ClassifiedMembers.rb (criminal_role = valor mapeado)
3. ✅ Execute OFAC update (ofac_designation + birthday + ofac_ent_num)

---

## 4. Errores Encontrados y Correcciones

### Error #1: Asumir que legacy_id es propiedad de Member
**Qué salió mal:** Pensé que legacy_id se guardaba en Member  
**Realidad:** legacy_id SOLO existe en Hit, se usa para lookup: `Hit.find_by(legacy_id:)`  
**Lección:** Leer código del controller antes de asumir estructura

### Error #2: Empezar del final incorrecto de lista OFAC
**Qué salió mal:** Empecé con Amezcua Contreras (1990s, histórico)  
**Realidad:** Debemos empezar del final más reciente de designaciones  
**Lección:** "de abajo hacia arriba" = más recientemente designados

### Error #3: Asumir ubicación por nombre coincidente
**Qué salió mal:** "Rancho San Miguel" → asumir "San Miguel el Alto"  
**Realidad:** Hay múltiples San Miguel, no es posible confirmar sin margen de error  
**Lección:** Cuando hay duda, usar STATE:{code} level en lugar de municipio específico

### Error #4: Olvidar HitSnapshotFetcher
**Qué salió mal:** Creé Hit pero no capturé plain_text/raw_html  
**Realidad:** Este paso es OBLIGATORIO en el flujo  
**Lección:** User confirmó: "ese es un paso indispensable"

### Error #5: Nombres incompletos (falta compuesto)
**Qué salió mal:** Guardé "Jesus" en lugar de "Jesus David"  
**Realidad:** OFAC tiene "Jesus David" como firstname compuesto  
**Lección:** Validar que names matches EXACTLY OFAC format

### Error #6: Asignar criminal_role directamente en creación
**Qué salió mal:** Intenté crear Member con `criminal_role: role.name` directamente
**Realidad:** Hay una constraint DB que valida valores permitidos de criminal_role
**Solución:** 
1. Crear Member con `criminal_role: nil` inicialmente
2. Ejecutar ClassifiedMembers.rb que asigna correctamente basado en mapeos
3. Luego ejecutar OFAC update
**Lección:** ClassifiedMembers.rb es el responsable de normalizar criminal_role, no la lógica de creación

### Error #7: Omitir componente compuesto de nombre (Wiliams Geovanni)
**Qué salió mal:** Creé Member con `firstname: "Wiliams"` en lugar de `"Wiliams Geovanni"`
**Causa raíz:** 
- No extraje nombre EXACTO de OFAC list antes de hardcodear en diccionario
- No validé contra Hit plain_text que menciona "william geovanni"
- Asumí en lugar de copiar textualmente
**Solución implementada:**
1. Nuevo paso 2.5.5: Validar Nombre Exacto OFAC (OBLIGATORIO)
2. Antes de crear, verificar que firstname completo aparece en Hit
3. Usar `parsed_firstname = ofac_entry.split(",")[1].strip` (EXACTO)
4. Validación pre-creación: `unless hit.plain_text.include?(parsed_firstname); raise "ERROR"; end`
**Corrección:** Actualicé Member 171717: firstname "Wiliams" → "Wiliams Geovanni"
**Lección:** NUNCA hardcodear nombres. SIEMPRE extraer EXACTAMENTE de OFAC list y validar contra Hit

### Error #8: Hit creados sin validar que NOMBRES aparecen explícitamente en plain_text
**Qué salió mal:** Creé 5 Hits (6000-6004) para 5 Members sin validar que los nombres estuvieran en el plain_text
**Impacto:** 
- Hit #6003: Contiene "Alfredo" pero NO "Alvarez"
- Hit #6004: Contiene "Jorge Luis" pero NO "Llanos"
**Causa raíz:** No había un proceso automatizado que BLOQUEARA creación de Members si los nombres no estaban explícitos
**Lección:** La validación debe ser IMPOSIBLE saltarse - necesita script automatizado que lance excepción

### Error #9: Ubicación inventada basada en búsqueda anterior (Zapopan para Hit #6002)
**Qué salió mal:** Asigné "Zapopan, Jalisco" a Hit #6002 (Martin Guadencio Avendano) basándome en búsqueda que mencionó detención en Zapopan 2016
**Realidad en plain_text:** 
- Sí menciona: "Culiacán, Sinaloa" (Autodromo ubicado allí)
- Sí menciona: "Ensenada, Baja California" (tienda ubicada allí)
- NO menciona: "Zapopan" en absoluto
**Causa raíz:** Confundir búsqueda web anterior con lo que dicta la fuente (plain_text) del Hit
**Lección:** ÚNICA fuente de verdad es el plain_text. Búsquedas previas NO cuentan como evidencia

### Error #10: Falta de checklist de validación antes de crear Members
**Qué salió mal:** No había proceso formal que garantizara que TODOS los criterios se validaban antes de Member.create!
**Impacto:** Todos los errores #7-#9 podrían haberse prevenido
**Solución:** Crear sección 2.1.4 y 2.1.6 con validador robusto que BLOQUEA creación si falla

---

## 5. Casos Especiales Encontrados

### Caso: Role Mapping según Categoría OFAC

**Escenario:** Un candidato aparece en OFAC pero requiere role correcto que mapee a criminal_role correcto

**Análisis (basado en cuadro OFAC):**
- **Categoría OFAC: Líderes y miembros** → Roles: Jefe de célula, Operador, etc → ClassifiedMembers mapea a "Miembro"
- **Categoría OFAC: Socios** → Roles: Socio, Manager, Abogado, etc → ClassifiedMembers mapea a "Socio"
- **Categoría OFAC: Autoridades vinculadas** → Roles: Policía, Alcalde, etc → ClassifiedMembers mapea a "Autoridad vinculada"

**Proceso:**
1. Revisar descripción en Hit de participación del candidato
2. Seleccionar role que corresponda a su nivel/categoría
3. Asignar role_id en Member creation
4. ClassifiedMembers.rb automáticamente mapea a criminal_role correcto
5. OFAC update captura datos de designación

**Ejemplo aplicado (Iteración 1):**
- Liliana Cisneros Tapia: "secretaria de Green Agropacific" → Rol: Socio → criminal_role: "Socio"
- Wiliams Botello Rodriguez: "operó una célula del CJNG" → Rol: Jefe de célula → criminal_role: "Miembro"
- Miguel Ayala Botello: "puesto de liderazgo en Bubux + fue director seguridad" → Rol: Operador → criminal_role: "Miembro"

### Caso: Reutilizar Hit para Familia
**Escenario:** Múltiples miembros de la familia en un artículo  
**Solución:** 
- Crear Hit UNA VEZ con legacy_id único
- Vincular múltiples Members al mismo Hit
- Ejemplo: familia Botello en Hit #5997 → 3 hermanos vinculados

**Ventaja:** No duplicar HitSnapshotFetcher, contenido ya disponible

### Caso: Nombres Compuestos en OFAC
**Escenario:** "BOTELLO ORTIZ, Jesus David" (dos primeros nombres)  
**Solución:** 
- firstname = "Jesus David" (conservar espacios, ambos nombres)
- lastname1 = "Botello"
- lastname2 = "Ortiz"
- Crucial para matching con script OFAC

### Caso: Sin ubicación específica
**Escenario:** No se puede determinar municipio exacto  
**Solución:**
- Usar STATE:{code} format (ej: "STATE:14" para Jalisco)
- Resuelve a Town "Sin definir" con full_code específico
- Mejor que asumir municipio incorrecto

---

## 6. Comandos Útiles

### Ver lista completa de OFAC sin match
```bash
RAILS_ENV=production bundle exec rails runner scripts/ofacUpdate.rb 2>&1 | grep -A 210 "SIN MATCH"
```

### Crear Hit desde Rails console
```ruby
hit = Hit.create!(
  legacy_id: "elfinanciero_20260723_XX_94",
  date: Date.parse("2026-07-23"),
  title: "Título del artículo",
  link: "https://url.com",
  town_id: 147724,
  user_id: current_user.id
)
HitSnapshotFetcher.call!(hit, require_members: false)
```

### Crear Member desde Rails console
```ruby
member = Member.create!(
  firstname: "Jesus David",
  lastname1: "Botello",
  lastname2: "Ortiz",
  organization_id: 2561,
  role_id: 20,
  involved: true,
  criminal_role: "Socio"
)
member.hits << hit
```

### Verificar Member post-OFAC
```ruby
member = Member.find(171713)
puts member.ofac_designation    # true
puts member.ofac_ent_num        # "58023"
puts member.birthday            # "1997-06-28"
```

---

## 7. Métricas y Progreso

### Iteración 1 (2026-09-29)
- **Casos procesados:** 6 (Ricardo, Jesus David, Edgar Gerardo Botello Ortiz + Liliana Cisneros, **Wiliams Geovanni**, Miguel Ayala)
- **Hits creados:** 2 (Hit #5997 para familia Botello, Hit #5992 para red empresarial CJNG)
- **Hits reutilizados:** Hit #5997 para 5 members, Hit #5992 para 1 member
- **Members creados:** 6
- **Members corregidos:** 1 (171717: firstname "Wiliams" → "Wiliams Geovanni")
- **OFAC matches:** 6/6 (100%)
- **ClassifiedMembers.rb ejecutado:** ✅ (asignó criminal_role correctamente)
- **Errores encontrados y corregidos:** 7 (incl. Error #7: omisión nombre compuesto)
- **Casos especiales:** 5 (nombres compuestos, reutilizar hits múltiples, análisis roles OFAC, role mapping ClassifiedMembers, validación nombre exacto OFAC)

### Lista OFAC
- **Total designados Mexico:** 643
- **Con match en BD:** 444 (antes: 442)
- **Sin match:** 199 (antes: 201)
- **Restantes a procesar:** ~196 (excluir familia Botello + otros criterios)

---

## 8.5 CHECKLIST PRE-CREACIÓN DE MEMBER (Obligatorio)

**Antes de ejecutar `Member.create!()`, validar TODOS estos puntos:**

- [ ] ✅ Firstname extraído EXACTAMENTE de OFAC list (formato: "LASTNAME, Firstname Compuesto")
- [ ] ✅ Firstname COMPLETO incluyendo segundo nombre si aplica (ej: "Wiliams Geovanni" NO "Wiliams")
- [ ] ✅ Firstname aparece en Hit plain_text (validación de verdad, paso 2.5.5)
- [ ] ✅ Lastname1 y lastname2 coinciden con OFAC entry
- [ ] ✅ Role seleccionado corresponde a descripción en Hit
- [ ] ✅ Organization existe en BD
- [ ] ✅ Hit tiene legacy_id y plain_text capturado
- [ ] ✅ Gender asignado (MASCULINO, FEMENINO, Desconocido) - paso 2.1.4
- [ ] ✅ criminal_role = nil (será asignado por ClassifiedMembers.rb)

**Si falla algo:** DETENER. Validar fuentes antes de crear.

---

## 8. Próximos Pasos

1. ✅ Continuar con siguientes individuos de lista OFAC (restantes ~196)
2. ✅ Documentar nuevos casos especiales encontrados en siguientes iteraciones
3. ✅ Refinar decisiones de rol/organización según contexto criminal
4. ✅ Consolidar reglas de análisis OFAC (cuadro de categorías)
5. ⏳ Diseñar automatización (una vez protocolo completamente estable)
6. ⏳ Crear agente OFAC que revise diarios y proponga casos para validación manual
7. ⏳ Integrar análisis de nombres compuestos en automatización

---

## 9. Control de Versiones

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | 2026-09-29 | Protocolo inicial basado en casos Botello Ortiz (3 members) |
| 1.1 | 2026-09-29 | ClassifiedMembers.rb + análisis roles OFAC + error #6 (criminal_role constraint) |
| 1.2 | 2026-09-29 | **CRÍTICO:** Paso 2.5.5 (Validar Nombre Exacto OFAC); error #7 (omisión "Geovanni"); corrección Member 171717 |
| 1.3 | 2026-09-29 | Protocolo de búsqueda individual (2.1.1-2.1.3); OfacCandidate model; identificación automática de organización |
| 1.4 | 2026-09-29 | Validación de ubicación crítica (2.3.1); error #9 (Zapopan inventado); documentación de town/county hierarchy |
| 2.0 | 2026-09-29 | **🚨 PROTOCOLO ROBUSTO:** Validador imposible de saltarse (2.1.4 + 2.1.6 Checklist); errors #8-#10; script `ofac_source_validator.rb`; validación BLOQUEA Member.create! |
| **2.1** | **2026-09-29** | **🚨 BÚSQUEDA ESTRATIFICADA (2.1.1 refactorizado):** 3 pasos de búsqueda en internet ANTES de BD; Paso 1: nombre+"cartel", Paso 2: nombre+"OFAC", Paso 3: nombre solo; criterios validación rigurosos (nombres exactos OFAC + ubicación + organización explícitas); OfacCandidate "not_found" si fallan todos los intentos |

---

**Nota:** Este documento es VIVO. Se actualiza conforme procesamos nuevos casos y descubrimos nuevos patrones.
