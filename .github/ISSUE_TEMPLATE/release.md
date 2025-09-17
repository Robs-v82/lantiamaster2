---
name: "RELEASE"
about: "Checklist breve para desplegar a producción"
title: "[RELEASE] <fecha y resumen>"
labels: ["release"]
---

## Alcance
- PRs incluidos: #
- Riesgo: Bajo / Medio / Alto

## Pre-deploy
- [ ] PRs aprobados y en `master`
- [ ] Migraciones con rollback probado (si aplica)
- [ ] Secrets/credentials revisados (cambios listados si aplica)
- [ ] Backups OK (RDS retention 7d) / DRP sin cambios
- [ ] Smoke tests listos (ver `docs/SMOKE_TESTS.md`)

## Deploy
- [ ] `cap production deploy` ejecutado sin errores
- [ ] Logs sanos tras deploy (Rails/Nginx)

## Post-deploy
- [ ] Smoke tests OK
- [ ] Monitoreo/errores sin anomalías
- [ ] Comunicaciones (si aplica) enviadas

## Notas / Evidencia
- Capturas / enlaces:
