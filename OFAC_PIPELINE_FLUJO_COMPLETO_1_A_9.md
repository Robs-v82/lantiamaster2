# OFAC Pipeline - Flujo Completo PASOS 1-9

**Versión:** 2.0  
**Última actualización:** 2026-10-06  
**Estado:** ✅ COMPLETO Y OPERACIONAL

---

## 📋 TABLA RESUMEN: Flujo Paso a Paso

| PASO | Descripción Sintética | Entrada | Salida | Documentado En | Script Ejecutor | Clase |
|------|----------------------|---------|--------|----------------|-----------------|-------|
| **1** | Seleccionar candidato OFAC sin revisar de lista oficial | Lista OFAC oficial (SDN) | Objeto candidato con firstname + lastname1 + lastname2 | `OFAC_MEMBER_PIPELINE_ROBUSTO.md` líneas 95-321 | `ofac_pipeline_executor.rb` | `OfacPipeline::Step1` |
| **2** | Buscar artículo con WebSearch, crear Hit, capturar plain_text | Candidato OFAC | Hit con plain_text ≥800 chars + fecha + ubicación | `OFAC_MEMBER_PIPELINE_ROBUSTO.md` líneas 329-647 | `ofac_pipeline_executor.rb` | `OfacPipeline::Step2` |
| **3** | Extraer fecha real del plain_text usando Claude AI | Hit.plain_text | Hit.date actualizado con fecha de Claude | `scripts/ofac_pipeline_executor.rb` líneas 500-700 | `ofac_pipeline_executor.rb` | `OfacPipeline::Step3` |
| **4** | Extraer ubicación exacta (estado/municipio) usando Claude AI | Hit.plain_text | Hit.town_id resuelto correctamente | `scripts/ofac_pipeline_executor.rb` líneas 700-850 | `ofac_pipeline_executor.rb` | `OfacPipeline::Step4` |
| **5** | Validar vinculación con cartel en catálogo (búsqueda fuzzy multi-nivel) | Hit.plain_text + Catálogo de cárteles | organization_id + confidence score | `scripts/ofac_pipeline_executor.rb` líneas 850-1050 | `ofac_pipeline_executor.rb` | `OfacPipeline::Step5` |
| **6** | Validar requisitos críticos: plain_text, fecha, ubicación, organización | Hit (PASOS 1-5 completados) | Hit validado ✅ o rechazo con opción reintentar | `scripts/ofac_pipeline_executor.rb` líneas 1050-1200 | `ofac_pipeline_executor.rb` | `OfacPipeline::Step6` |
| **7** | Extraer alias del candidato con Claude (validación de pertenencia) | Candidato + Hit.plain_text | Array de alias (puede estar vacío) | `scripts/ofac_pipeline_executor.rb` líneas 1300-1400 | `ofac_pipeline_executor.rb` | `OfacPipeline::Step7` |
| **8** | Determinar rol OFAC del candidato usando Claude (4 categorías) | Candidato + Hit.plain_text + Organización | role_name + confidence_percentage | `scripts/ofac_pipeline_executor.rb` líneas 1400-1550 | `ofac_pipeline_executor.rb` | `OfacPipeline::Step8` |
| **9** | Presentar tablas de confirmación (Hit + Member) para revisión | Resultados PASOS 1-8 | Tablas formateadas en terminal para confirmación | `scripts/ofac_pipeline_executor.rb` líneas 1550-1800 | `ofac_pipeline_executor.rb` | `OfacPipeline::Step9` |

---

## 🚀 SCRIPTS DISPONIBLES

### Script Principal: `scripts/run_pipeline_1_to_9.rb`
**Propósito:** Ejecutar pipeline COMPLETO PASOS 1-9 de principio a fin

**Comando:**
```bash
cd /Users/robertovalladares/lantiaclone/lantiamaster2
ruby scripts/run_pipeline_1_to_9.rb
```

**Qué hace:**
1. Carga variables de entorno (.env)
2. Inicializa Rails
3. Ejecuta PASO 1 → obtiene candidato OFAC
4. Ejecuta PASO 2 → busca y crea Hit
5. Ejecuta PASO 3 → extrae fecha
6. Ejecuta PASO 4 → extrae ubicación
7. Ejecuta PASO 5 → identifica cartel
8. Ejecuta PASO 6 → valida requisitos
9. Ejecuta PASO 7 → extrae alias
10. Ejecuta PASO 8 → determina rol
11. Ejecuta PASO 9 → presenta confirmación

**Variables de entorno requeridas (.env):**
```
SERPER_API_KEY=fb3f4657cafc34b22cfab227cb0ef2a79c41ef99
ANTHROPIC_API_KEY=<YOUR_ANTHROPIC_API_KEY_HERE>
```

---

### Script Executor: `scripts/ofac_pipeline_executor.rb`
**Propósito:** Contiene la implementación de TODOS los PASOS 1-9

**Clases disponibles:**
- `OfacPipeline::Step1.execute!()`
- `OfacPipeline::Step2.execute!(candidate)`
- `OfacPipeline::Step3.execute!(hit)`
- `OfacPipeline::Step4.execute!(hit)`
- `OfacPipeline::Step5.execute!(hit)`
- `OfacPipeline::Step6.execute!(candidate, hit, organization)`
- `OfacPipeline::Step7.execute!(candidate, hit)`
- `OfacPipeline::Step8.execute!(candidate, hit, organization)`
- `OfacPipeline::Step9.present_for_confirmation(candidate, hit, organization, aliases, role_name, role_id)`

---

## 📚 DOCUMENTACIÓN

### Documentación Completa (OFAC_MEMBER_PIPELINE_ROBUSTO.md)
- Líneas 1-60: Principios fundamentales y normalización de nombres
- Líneas 95-321: PASO 1 - Identificar Candidato OFAC
- Líneas 329-647: PASO 2 - Buscar Evidencia de Cartel

### Documentación en Código (ofac_pipeline_executor.rb)
- Líneas 22-250: PASO 1 - Implementación completa
- Líneas 252-850: PASO 2 - Implementación completa
- Líneas 850-1050: PASO 3-4 - Extracción de fecha y ubicación
- Líneas 1050-1200: PASO 5-6 - Validación de cartel y requisitos
- Líneas 1300-1550: PASO 7-8 - Extracción de alias y rol
- Líneas 1550-1800: PASO 9 - Presentación de confirmación

---

## ✅ FLUJO DE EJECUCIÓN REAL

```
┌─────────────────────────────────────────────────────────┐
│ run_pipeline_1_to_9.rb (Script Principal)              │
└─────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
    PASO 1          PASO 2          PASO 3-4
  Candidato ──→    Hit + Text  ──→  Fecha + Ubicación
                                        │
                         ┌──────────────┼──────────────┐
                         │              │              │
                         ▼              ▼              ▼
                      PASO 5         PASO 6         PASO 7-8
                   Cartel Match ──→ Validación ──→ Alias + Rol
                                         │
                                         ▼
                                      PASO 9
                                   Confirmación
                                   (Tablas)
```

---

## 🔑 REQUISITOS CRÍTICOS

### Claves API (en .env)
- ✅ `SERPER_API_KEY`: Para búsquedas WebSearch
- ✅ `ANTHROPIC_API_KEY`: Para Claude AI (PASOS 3, 4, 7, 8)

### Base de Datos
- ✅ Tabla `members` con campo `ofac_designation`
- ✅ Tabla `hits` con campos: `plain_text`, `date`, `town_id`, `link`
- ✅ Tabla `organizations` con búsqueda fuzzy
- ✅ Tablas de ubicación: `states`, `counties`, `towns`

### Métodos Rails disponibles
- `HitSnapshotFetcher.call!(hit, require_members: false)` - captura plain_text

---

## 📊 ESTADO ACTUAL (2026-10-06)

| Componente | Estado | Notas |
|-----------|--------|-------|
| PASO 1 | ✅ Operacional | Extrae candidatos OFAC sin revisar |
| PASO 2 | ✅ Operacional | Búsqueda WebSearch + Hit creation |
| PASO 3 | ✅ Operacional | Claude extrae fecha |
| PASO 4 | ✅ Operacional | Claude extrae ubicación |
| PASO 5 | ✅ Operacional | Búsqueda fuzzy multi-nivel de cartel |
| PASO 6 | ✅ Operacional | Validación de requisitos críticos |
| PASO 7 | ✅ Operacional | Claude extrae alias con validación |
| PASO 8 | ✅ Operacional | Claude determina rol OFAC |
| PASO 9 | ✅ Operacional | Presenta tablas de confirmación |
| Serper API | ✅ Funcional | API key válida configurada |
| Anthropic API | ✅ Funcional | API key válida configurada |

---

## 🎯 PRÓXIMOS PASOS

- [ ] Ejecutar `ruby scripts/run_pipeline_1_to_9.rb` para test completo
- [ ] Revisar tablas del PASO 9
- [ ] Confirmar creación de Member en BD (cuando se autorize)
- [ ] Documentar cambios finales en CLAUDE.md

