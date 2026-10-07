# OFAC Pipeline Completo - Documentación Unificada

**Versión:** 2.0  
**Última actualización:** 2026-10-06  
**Estado:** ✅ PASOS 1-5 OPERACIONALES | PASOS 6-9 EN DESARROLLO

---

## 🎯 DESCRIPCIÓN GENERAL

Pipeline OFAC de 9 pasos para procesar candidatos de la lista de designaciones del Tesoro estadounidense (OFAC SDN) y validarlos contra cárteles mexicanos en el catálogo. Integra búsqueda web (Serper), extracción de contenido (HitSnapshotFetcher), e inteligencia artificial (Claude) para automatizar la validación de vinculaciones criminales.

---

## 📋 TABLA RESUMEN: Flujo Paso a Paso

| PASO | Descripción | Entrada | Salida | Estado | Clase |
|------|-------------|---------|--------|--------|-------|
| **1** | Seleccionar candidato OFAC sin revisar | Lista OFAC oficial (SDN) | Objeto candidato (firstname + lastname1 + lastname2) | ✅ Operacional | `OfacPipeline::Step1` |
| **2** | Buscar artículo WebSearch, crear Hit, capturar plain_text | Candidato OFAC | Hit con plain_text ≥800 chars + fecha + ubicación | ✅ Operacional | `OfacPipeline::Step2` |
| **3** | Extraer fecha real del plain_text con Claude AI | Hit.plain_text | Hit.date actualizado | ✅ Operacional | `OfacPipeline::Step3` |
| **4** | Extraer ubicación (estado/municipio) con Claude AI | Hit.plain_text | Hit.town_id resuelto | ✅ Operacional | `OfacPipeline::Step4` |
| **5** | Validar vinculación con cartel (búsqueda fuzzy multi-nivel) | Hit.plain_text + Catálogo | organization_id + confidence | ✅ Operacional | `OfacPipeline::Step5` |
| **6** | Validar requisitos críticos post-procesamiento | Hit (PASOS 1-5) | Hit validado ✅ o rechazo | 🔄 Pendiente | `OfacPipeline::Step6` |
| **7** | Extraer alias del candidato con Claude | Candidato + Hit.plain_text | Array de alias | 🔄 Pendiente | `OfacPipeline::Step7` |
| **8** | Determinar rol OFAC con Claude (4 categorías) | Candidato + Hit + Organización | role_name + confidence | 🔄 Pendiente | `OfacPipeline::Step8` |
| **9** | Presentar tablas de confirmación para revisión | Resultados PASOS 1-8 | Tablas formateadas en terminal | 🔄 Pendiente | `OfacPipeline::Step9` |

---

## 🚀 SCRIPTS EJECUTABLES

### Script Principal: `scripts/ofac_pipeline_main.rb`
**Propósito:** Ejecutar PASOS 1-5 del pipeline de principio a fin

**Comando:**
```bash
cd /Users/robertovalladares/lantiaclone/lantiamaster2
ruby scripts/ofac_pipeline_main.rb
```

**Qué hace:**
1. Carga variables de entorno (.env)
2. Inicializa Rails
3. PASO 1: Selecciona candidato OFAC sin revisar
4. PASO 2: Busca artículo con WebSearch, crea Hit, captura plain_text
5. PASO 3: Extrae fecha real con Claude
6. PASO 4: Extrae ubicación con Claude
7. PASO 5: Valida vinculación con cartel en catálogo

**Variables de entorno requeridas (.env):**
```
SERPER_API_KEY=fb3f4657cafc34b22cfab227cb0ef2a79c41ef99
ANTHROPIC_API_KEY=<YOUR_ANTHROPIC_API_KEY_HERE>
```

### Script Completo (PASOS 1-9): `scripts/run_pipeline_1_to_9.rb`
**Propósito:** Ejecutar pipeline COMPLETO PASOS 1-9 (PASOS 6-9 pendientes de finalización)

**Comando:**
```bash
ruby scripts/run_pipeline_1_to_9.rb
```

### Script Executor: `scripts/ofac_pipeline_executor.rb`
**Propósito:** Contiene la implementación de TODOS los PASOS 1-9

**Clases disponibles:**
```ruby
OfacPipeline::Step1.execute!                                    # → candidato
OfacPipeline::Step2.execute!(candidate)                         # → hit
OfacPipeline::Step3.execute!(hit)                               # → { date: ... }
OfacPipeline::Step4.execute!(hit)                               # → { location: ... }
OfacPipeline::Step5.execute!(hit)                               # → { organization: ... }
OfacPipeline::Step6.execute!(candidate, hit, organization)      # → { valid: true/false }
OfacPipeline::Step7.execute!(candidate, hit)                    # → { aliases: [...] }
OfacPipeline::Step8.execute!(candidate, hit, organization)      # → { role: ... }
OfacPipeline::Step9.present_for_confirmation(...)               # → imprime tablas
```

---

## 📚 DOCUMENTACIÓN DETALLADA POR PASO

### 🚨 Principio Fundamental

**Cada validación es CODE, no intención.** Toda decisión se bloquea con excepciones si falla.  
No hay "asumir", no hay "olvidar". Todo falla explícitamente o continúa.

---

### 📋 Normalización de Nombres (CRÍTICA PARA VALIDACIONES)

**Problema:** Nombres OFAC vienen con:
- Todo MAYÚSCULAS: `"GARCÍA LÓPEZ"`
- Formato invertido: `"LASTNAME, Firstname"` en lugar de `"Firstname Lastname"`
- Acentos inconsistentes: `"María"` vs `"Maria"`
- Ñ vs N: `"PEÑA"` vs `"PENA"`

**Solución:** Convertir a formato `fullname` equivalente a `Member.fullname` para validación directa

**Funciones de Normalización:**
```ruby
def normalize_and_capitalize(text)
  # Transliterar acentos + Title Case
  # "MARÍA GARCÍA" → "Maria Garcia"
  # "maría garcía" → "Maria Garcia"
  I18n.transliterate(text.to_s.strip).split.map(&:capitalize).join(" ")
end

def normalize_for_search(text)
  # Para búsquedas case-insensitive + sin acentos
  # "Maria Del Rosario" → "maria del rosario"
  I18n.transliterate(text.to_s.strip.downcase)
end
```

**Ejemplo Completo:**
- ENTRADA OFAC: `"GARCÍA LÓPEZ, María del Rosario"`
- SALIDA NORMALIZADA: `"Maria Del Rosario Garcia Lopez"`
- VALIDACIÓN: Comparación directa con `Member.fullname`

---

### PASO 1: Identificar Candidato OFAC Disponible

#### QUÉ (Descripción)

Extraer del listado OFAC "SIN MATCH" el candidato MÁS RECIENTE que:
- Tiene estructura de nombre válida: **firstname + lastname1 + lastname2** (mínimo 3 componentes)
- **NO está** en la tabla `ofac_candidates` (ya fue revisado anteriormente)

**Salida esperada:**
- ✅ **Si existe:** Retorna OBJETO con datos del candidato OFAC
  ```ruby
  {
    ofac_name: "MORENO GOMEZ SANTELICES, Marco Antonio",
    fullname: "Marco Antonio Moreno Gomez Santelices",
    firstname: "Marco Antonio",
    lastname1: "Moreno",
    lastname2: "Gomez Santelices"
  }
  ```
- ❌ **Si NO existe:** Retorna nil + mensaje "No hay candidatos OFAC disponibles"

#### Validaciones Explícitas

**VALIDACIÓN 1: OFAC List existe**
- ✅ Descarga archivos sdn.csv y add.csv de treasury.gov sin errores
- ✅ Genera lista "SIN MATCH" válida con individuales mexicanos
- ❌ Si falla: Lanza excepción

**VALIDACIÓN 2: Estructura de nombre válida**
- Input: `"LASTNAME, Firstname Compuesto Opcional"`
- ✅ Parsea correctamente con split en coma
- ✅ Firstname tiene 1+ tokens, Lastname tiene 2+ tokens
- ❌ Si falla: Excluye el candidato silenciosamente

**VALIDACIÓN 3: NO está en OfacCandidate**
- Búsqueda: `OfacCandidate.find_by(ofac_name: ...)`
- ✅ Si es nil: candidato es elegible
- ❌ Si existe: candidato ya fue revisado, excluir

**VALIDACIÓN 4: Retorna último de lista**
- ✅ De los candidatos elegibles, retorna el ÚLTIMO (más reciente)

---

### PASO 2: Buscar Evidencia de Cartel y Crear Hit Provisional

#### QUÉ (Descripción)

Buscar en internet artículos que vinculen al candidato OFAC con un cartel en el catálogo.
Si se encuentra un artículo:
1. Resolver municipio/estado (jerarquía obligatoria)
2. Crear Hit provisional (con link del artículo)
3. Capturar `plain_text` usando `HitSnapshotFetcher` (**OBLIGATORIO**)
4. Validar que candidato aparece en el plain_text

**Salida esperada:**
- ✅ **Si éxito:** Retorna Hit object con `plain_text` capturado (≥800 chars), ubicación resuelta, link válido
- ❌ **Si falla plain_text:** Destruye Hit (si es nuevo), intenta siguiente resultado
- ❌ **Si no hay resultados:** Retorna nil

#### Validaciones Explícitas

**VALIDACIÓN 1: WebSearch retorna resultados**
- ✅ Query: `"{{fullname}}" Cartel`
- ✅ Se obtiene array de artículos con 10 resultados
- ❌ Si no hay resultados: retorna nil

**VALIDACIÓN 2: Artículo tiene link válido**
- ✅ `result[:url].present?` y es URL válida
- ❌ Si no tiene link: continúa al siguiente artículo

**VALIDACIÓN 3: Se resuelve municipio/estado según reglas obligatorias**

Flujo de resolución (EN ORDEN):
```
1. Identificar ESTADO en el texto del artículo
   ├─ Si se identificó Estado Y Municipio:
   │  └─ Buscar Town "Sin definir" dentro de ese Municipio
   ├─ Si se identificó SOLO Estado:
   │  └─ Elegir Town "Sin definir" del Municipio "Sin definir" de ese Estado
   └─ Si NO se identificó nada OR es extranjero:
      └─ Elegir Town "Sin definir" del Municipio "Sin definir" de CDMX (fallback)
```

**VALIDACIÓN 4: Hit se crea con datos válidos**
- ✅ `Hit.create!(date: date, title: title, link: url, town_id: town_id)`
- ✅ Hit tiene link único (validación en modelo)
- ❌ Si falla: excepción, no continúa

**VALIDACIÓN 5: plain_text se captura exitosamente (CRÍTICA)**
- ✅ `HitSnapshotFetcher.call!(hit, require_members: false)` sin error
- ✅ `hit.plain_text.present?` y `hit.plain_text.length >= 800`
- ✅ Candidato aparece en plain_text (validación de relevancia)
- ❌ Si falla: Destruye Hit (solo si es nuevo) y continúa a siguiente artículo

---

### PASO 3: Extraer Fecha Real con Claude

#### QUÉ

Extrae la fecha de publicación real del artículo usando Claude AI. Esta fecha reemplaza la fecha provisional `Date.today` que se asignó en PASO 2.

**Entrada:** `Hit.plain_text` (primeros 2000 caracteres)
**Salida:** `Hit.date` actualizado con fecha YYYY-MM-DD

#### Validación

- ✅ Claude retorna fecha en formato YYYY-MM-DD (e.g., "2026-10-01")
- ✅ Validar que fecha es válida (no futura, no más de 1 año atrás)
- ✅ Actualizar `hit.date` con la fecha extraída
- ✅ **Si Claude falla o retorna fecha inválida:** Usar fallback garantizado `Date.today`
  - El fallback NO es opcional
  - Cada Hit DEBE tener una fecha válida

#### Resultado Real (2026-10-06)
```
🤖 PASO 3: Extrayendo fecha con Claude...
============================================================
✅ Fecha extraída por Claude: 2026-10-01
```

---

### PASO 4: Extraer Ubicación con Claude

#### QUÉ

Extrae la ubicación exacta (estado/municipio) del artículo usando Claude AI. Reemplaza la ubicación provisional asignada en PASO 2.

**Entrada:** `Hit.plain_text` (primeros 2000 caracteres)
**Salida:** `Hit.town_id` resuelto correctamente, Location: "Municipio, Estado"

#### Validación

- ✅ Claude retorna JSON con campos `state` y `county`
- ✅ Buscar Town correspondiente en BD
- ✅ Si Claude no encuentra ubicación: Usar fallback "Sin definir, CDMX"
- ✅ Validar que Town existe en BD antes de actualizar

#### Resultado Real (2026-10-06)
```
🤖 PASO 4: Extrayendo ubicación con Claude...
============================================================
✅ Ubicación actualizada
```

---

### PASO 5: Validar Vinculación con Cartel en Catálogo

#### QUÉ

Busca en el catálogo de organizaciones criminales si existe un match con el cartel mencionado en el plain_text. Utiliza búsqueda fuzzy multi-nivel:
- Level 1: Búsqueda exacta en campo `name`
- Level 2: Búsqueda fuzzy en campo `name`
- Level 3: Búsqueda en campos alias/legacy_names

**Entrada:** `Hit.plain_text`
**Salida:** `Organization` encontrada + confidence score (0-100%)

#### Validación

- ✅ Busca cartel mencionado en plain_text contra catálogo
- ✅ Retorna match encontrado con confidence score
- ✅ Si no hay match: confidence = 0%

#### Resultado Real (2026-10-06)
```
🤖 PASO 5: Validando vinculación con cartel en catálogo...
   ✅ Vinculación encontrada: Cártel de Sinaloa
      Confianza: 100%
      Campo: name
      Valor coincidente: 'Cártel de Sinaloa'
      Tipo match: name
```

---

## 🔑 REQUISITOS CRÍTICOS

### Claves API (en .env)
- ✅ `SERPER_API_KEY`: Para búsquedas WebSearch (noticias de Google)
- ✅ `ANTHROPIC_API_KEY`: Para Claude AI (PASOS 3, 4, 5, 7, 8)

### Base de Datos
- ✅ Tabla `members` con campo `ofac_designation`
- ✅ Tabla `hits` con campos: `plain_text`, `date`, `town_id`, `link`
- ✅ Tabla `organizations` con búsqueda fuzzy
- ✅ Tablas de ubicación: `states`, `counties`, `towns`
- ✅ Tabla `ofac_candidates` para tracking

### Métodos Rails disponibles
- `HitSnapshotFetcher.call!(hit, require_members: false)` - captura plain_text
- `I18n.transliterate(text)` - normalización de acentos

---

## 📊 ESTADO ACTUAL (2026-10-06)

**Ejecución Exitosa de PASOS 1-5:**
```
Candidato: Marco Antonio Moreno Gomez Santelices
Hit ID: 6026
Fecha (PASO 3): 2026-10-01
Ubicación (PASO 4): Tijuana, Baja California
Cartel (PASO 5): Cártel de Sinaloa (Confianza: 100%)
Plain text: 13059 caracteres
```

| Componente | Estado | Notas |
|-----------|--------|-------|
| PASO 1 | ✅ Operacional | Extrae candidatos OFAC sin revisar |
| PASO 2 | ✅ Operacional | Búsqueda WebSearch + Hit creation |
| PASO 3 | ✅ Operacional | Claude extrae fecha con fallback |
| PASO 4 | ✅ Operacional | Claude extrae ubicación con fallback |
| PASO 5 | ✅ Operacional | Búsqueda fuzzy multi-nivel de cartel |
| PASO 6 | 🔄 Pendiente | Validación de requisitos críticos |
| PASO 7 | 🔄 Pendiente | Claude extrae alias con validación |
| PASO 8 | 🔄 Pendiente | Claude determina rol OFAC |
| PASO 9 | 🔄 Pendiente | Presenta tablas de confirmación |
| Serper API | ✅ Funcional | API key válida configurada |
| Anthropic API | ✅ Funcional | API key válida configurada |

---

## 🎯 PRÓXIMOS PASOS

- [ ] Implementar PASO 6: Validación de requisitos críticos post-procesamiento
- [ ] Implementar PASO 7: Extracción de alias con validación
- [ ] Implementar PASO 8: Determinación de rol OFAC (4 categorías)
- [ ] Implementar PASO 9: Presentación de tablas de confirmación
- [ ] Actualizar script principal `ofac_pipeline_main.rb` para incluir PASOS 6-9
- [ ] Ejecutar `ruby scripts/run_pipeline_1_to_9.rb` para test completo
- [ ] Revisar tablas del PASO 9
- [ ] Confirmar creación de Member en BD (cuando se autorize)

---

## 📖 HISTORIAL DE VERSIONES

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 2.0 | 2026-10-06 | Consolidación completa de documentación: PASOS 1-5 operacionales, estructura unificada |
| 1.5 | 2026-10-06 | PASOS 1-5 refactorizados como independientes, extracción de Step3 y Step4 |
| 1.1 | 2026-09-30 | PASO 2 completo: Búsqueda de cartel + Hit provisional con plain_text |
| 1.0 | 2026-09-30 | PASO 1 completo: Identificar Candidato OFAC Disponible |

---

**Control de calidad:** Documentación verificada contra script executor activo en producción (2026-10-06).
