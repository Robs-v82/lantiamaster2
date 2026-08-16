# CLAUDE.md - Directivas de Trabajo Críticas

**Última actualización:** 2026-08-16

## ⚠️ REGLA OBLIGATORIA: Flujo de Cambios

**NUNCA hacer commit, push o deploy sin visto bueno explícito del usuario.**

### Flujo OBLIGATORIO (SIN EXCEPCIONES):

```
1. DIAGNÓSTICO
   → Explicar qué está mal, dónde, por qué

2. PROPUESTA
   → Mostrar código exacto a cambiar
   → Explicar qué se va a hacer

3. ESPERAR VISTO BUENO
   → Usuario dice "sí", "adelante", "hazlo"
   → Usuario aprueba o pide cambios en la propuesta

4. SOLO ENTONCES: EJECUTAR
   → Editar archivos
   → Hacer commit (con Co-Authored-By)
   → Hacer push
   → Hacer deploy (si se requiere)
```

### Esto NO es opcional

Incluso si:
- El problema es "obvio"
- La solución es "clara"  
- Es "solo una línea"
- Estoy "seguro" de que es correcto

**SIEMPRE ESPERAR VISTO BUENO.** Sin excepciones.

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

**Si violas esta regla:** Rompes confianza y puedes causar daño en producción. NUNCA hacer commits, pushes o deploys sin visto bueno explícito.
