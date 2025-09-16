# Severidad de incidentes
- **P0**: Caída total de dashboard o fuga activa de datos. Impacto crítico. Tiempo objetivo: atención inmediata.
- **P1**: Degradación severa (login falla para >20% o tiempos >10s). Atención <30 min.
- **P2**: Error funcional relevante sin impacto masivo. Atención en día hábil.
- **P3**: Hallazgo menor / consulta.

**Disparadores P0**: downtime total, credenciales expuestas, borrado masivo, RDS inaccesible.
**Cierre**: servicio estable + causa conocida + acciones correctivas definidas.
