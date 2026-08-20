# CLAUDE.md - Directivas de Trabajo Críticas

**Última actualización:** 2026-08-20

## 🚨 REGLA OBLIGATORIA #1: Reutilización de Código Análogo

**ANTES de escribir CUALQUIER código nuevo, REVISA si existe código análogo en el proyecto.**

### El Principio:
```
ENCONTRAR → COPIAR ÍNTEGRAMENTE → ADAPTAR
    ≠
ESCRIBIR DESDE CERO
```

### Protocolo Obligatorio:

**Paso 1: BUSCAR código análogo**
- ¿Ya existe un controlador parecido? → Úsalo como base
- ¿Ya existe una vista similar? → Cópiala y adapta
- ¿Ya existe un método con lógica parecida? → Reutiliza
- ¿Ya existe un formato/estilo? → Sigue el patrón

**Paso 2: COPIAR ÍNTEGRAMENTE**
- Copia el código COMPLETO, no fragmentos
- Verifica que copiaste TODOOOO (línea inicial a final)
- NO uses sed/grep para extraer (error-prone)
- LEE el archivo completo manualmente

**Paso 3: ADAPTAR necesariamente**
- Cambia SOLO lo que debe cambiar
- Mantén estructura, estilo, convenciones
- Mantén lógica de validación y manejo de errores
- Documenta qué adaptaste y por qué

### Por qué Esto Es Obligatorio:

✅ **Consistencia:** Mismo estilo en todo el código
✅ **Reducción de errores:** No reinventar la rueda
✅ **Mantenibilidad:** Patrones conocidos = menos bugs
✅ **Validación:** Código que funciona como base = confianza
✅ **Velocidad:** Copiar+adaptar es más rápido que escribir

### Esto NO es opcional

Incluso si:
- "Es más fácil escribir desde cero"
- "El código existente es 'un poco diferente'"
- "Puedo hacerlo mejor"

**REVISA PRIMERO. COPIA. ADAPTA. SIN EXCEPCIONES.**

---

## ⚠️ REGLA OBLIGATORIA #2: Flujo de Cambios

**VISTO BUENO ≠ AUTORIZACIÓN PARA COMMIT/PUSH/DEPLOY**

### Flujo OBLIGATORIO (SIN EXCEPCIONES):

```
1. DIAGNÓSTICO
   → Explicar qué está mal, dónde, por qué

2. PROPUESTA
   → Mostrar código exacto a cambiar
   → Explicar qué se va a hacer

3. ESPERAR VISTO BUENO
   → Usuario dice "sí", "adelante", "hazlo"
   → Usuario aprueba la propuesta

4. EDITAR CÓDIGO (SIN COMMIT/PUSH/DEPLOY)
   → Editar archivos SOLO
   → Cambios locales únicamente
   → SIN hacer commit

5. COMMIT, PUSH Y DEPLOY
   → SOLAMENTE cuando usuario diga EXPLÍCITAMENTE:
     "haz commit", "haz push", "haz deploy"
   → O una instrucción que incluya estas acciones explícitamente
   → NO asumir nunca que visto bueno = commit/push/deploy
```

### Esto NO es opcional

Incluso si:
- El problema es "obvio"
- La solución es "clara"  
- Es "solo una línea"
- Estoy "seguro" de que es correcto
- El usuario dijo "adelante" o "sí" a la propuesta

**NUNCA hacer commit, push o deploy sin INSTRUCCIÓN EXPLÍCITA.** Sin excepciones.

## Otras Reglas de Trabajo

1. **Respuestas concisas** — Siempre breves, sin divagaciones
2. **Diagnóstico primero** — Nunca asumir; siempre diagnosticar
3. **Propuesta clara** — Mostrar código específico, no ideas vagas
4. **Visto bueno** — Esperar confirmación explícita del usuario

## Por qué Esto Es Crítico

- Cambios no autorizados pueden romper producción
- Pérdida de control = pérdida de confianza
- Sistemas vivos requieren aprobación explícita

---

## 📋 PROTOCOLO DE VALIDACIÓN: Replicación de Código

Cuando copies y adaptes código existente:

1. ✅ **VERIFICA COMPLETITUD**
   - ¿Copiaste línea inicial a final?
   - ¿Todas las funciones/métodos están?
   - Usa Read, no sed/grep

2. ✅ **VERIFICA COMPILACIÓN**
   - `ruby -c` para .rb
   - Sintaxis sin errores

3. ✅ **VERIFICA LÓGICA**
   - Las adaptaciones mantienen intención original
   - No eliminaste validaciones por error
   - Manejo de errores intacto

4. ✅ **VERIFICA ESTRUCTURA**
   - Mismo patrón/estilo que original
   - Mismos nombres de variables (donde aplica)
   - Mismo formato de código

---

## 📋 VERIFICACIÓN: Features Multi-Componente

Cuando editas features con múltiples partes (controller, view, JavaScript, PDF):

1. ✅ **DELIMITA CAMBIOS**
   - Edita SOLO el componente que falla
   - Marca claramente inicio y fin de cambios
   - NO toques componentes sin error

2. ✅ **PRUEBA INDEPENDIENTE**
   - Verifica que cada componente funciona solo
   - Upload CSV funciona sin PDF
   - PDF genera sin tocar upload flow

3. ✅ **PRUEBA FLUJO COMPLETO**
   - Ejecuta proceso entero
   - Verifica que todos los pasos funcionan juntos
   - Sin errores de cascada

---

## 📋 ESTÁNDAR: Paridad de Contenido (UI + PDF)

Para features que generan output en múltiples formatos:

1. ✅ **PALABRAS IDÉNTICAS**
   - Mismo label en pantalla y PDF
   - Mismo texto en botones, títulos, leyendas
   - No "matches" en un lado y "coincidencias" en otro

2. ✅ **DATOS IDÉNTICOS**
   - Mismos campos mostrados
   - Mismo orden de columnas
   - Nada falta, nada sobra

3. ✅ **ESTRUCTURA IDÉNTICA**
   - Mismo orden de secciones
   - Leyendas en mismo lugar
   - Tablas con mismos encabezados

4. ✅ **VALIDACIÓN**
   - Generar output en ambos formatos
   - Comparar lado a lado
   - 100% coincidencia en contenido (palabras exactas)

---

## ✅ CHECKLIST: Antes de Commit/Push/Deploy

**NUNCA hagas commit sin verificar esto:**

- [ ] Sintaxis Ruby: `ruby -c [archivo.rb]`
- [ ] Rutas: todas las rutas del features existen
- [ ] Referencias: no hay variables/métodos undefined
- [ ] Assets: CSS/JavaScript compilan sin errores
- [ ] Multi-componente: flujo COMPLETO funciona
- [ ] Paridad: contenido en todos los formatos es idéntico
- [ ] Validación: el feature original sigue funcionando
- [ ] No regressions: nada que funcione antes ahora está roto

**Regla:** No hay excusas. Esta lista se verifica SIEMPRE.

---

**Si violas estas reglas:** Rompes confianza y puedes causar daño en producción. SIEMPRE reusa código análogo, SIEMPRE verifica completitud, SIEMPRE valida pre-producción, NUNCA hagas commits sin visto bueno explícito.
