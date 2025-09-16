## Resumen breve
<!-- ¿Qué cambia y por qué? -->

## Riesgo del cambio
- [ ] Bajo (sin lógica sensible)
- [ ] Medio (lógica o UI relevante)
- [ ] Alto (auth, permisos, secrets, pagos, infraestructura)

## Checklist de seguridad
- [ ] No introduzco credenciales en el código (se usan ENV/credentials)
- [ ] Si cambié autenticación/autorización, documenté el flujo y probé MFA
- [ ] Si hay migraciones: incluyen **rollback** y se probó en staging
- [ ] No se filtra PII en logs (revisé logs y `Rails.logger`)
- [ ] Si toqué cabeceras/CSP/SRI, validé con Mozilla Observatory
- [ ] Dependencias nuevas/actualizadas revisadas (licencia y origen)
- [ ] Llamadas externas justificadas (dominio/puertos) y con timeouts
- [ ] Manejo de errores sin mostrar stack/secretos al usuario
- [ ] Métricas/alertas siguen funcionando o se actualizaron
- [ ] Añadí/actualicé tests relevantes

## Evidencia de pruebas
<!-- comandos, capturas, enlaces a issue/ticket -->

## Impacto en despliegue
- [ ] Sin pasos extra
- [ ] Requiere variables/credentials nuevas (listarlas)
- [ ] Requiere tareas post-deploy (cuáles)
