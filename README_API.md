cat > README_API.md <<'MD'
# Lantia API (v1) — Onboarding rápido

## Endpoint
POST /api/v1/members/search

## Autenticación
Envía tu API key en uno de estos headers:
- X-API-KEY: <api_key>
- Authorization: Bearer <api_key>

## Requests (2 modos)

### 1) Modo name (nombre completo)
Requiere: name (mín. 4 caracteres).  

Ejemplo:
curl -s -X POST https://TU_DOMINIO/api/v1/members/search -H "Content-Type: application/json" -H "X-API-KEY: TU_API_KEY" -d '{"name":"juan perez lopez"}'

### 2) Modo segmentado (3 campos)
Requiere: firstname, lastname1, lastname2 (mín. 2 caracteres cada uno).  

Ejemplo:
curl -s -X POST https://TU_DOMINIO/api/v1/members/search -H "Content-Type: application/json" -H "X-API-KEY: TU_API_KEY" -d '{"firstname":"juan","lastname1":"perez","lastname2":"lopez"}'

## Respuesta (200)
- request_id: identificador para soporte y trazabilidad
- meta.api_version: "v1"
- meta.plan / limit / used / remaining: cuota y uso
- results.count: número de resultados
- results.members: lista de perfiles

## Errores
- 401 unauthorized: API key ausente o inválida
- 403 forbidden: organización sin acceso activo a la API
- 422 invalid_request: parámetros incompletos/invalidos
- 429 rate_limit_exceeded: excediste la cuota del plan
- 500 internal_error: error interno (usa request_id para soporte)

## Buenas prácticas
- Guarda el request_id de cada consulta.
- En 429, reduce frecuencia o solicita aumento de cuota.
MD