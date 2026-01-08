# Members Search API (v1)

Este endpoint permite buscar registros de personas físicas (Members) usando:
- un nombre completo (`name`), o
- nombre segmentado (`firstname`, `lastname1`, `lastname2`).

La respuesta está en JSON e incluye la misma información que se muestra en la vista `members_outcome` (sin mapa).

---

## Endpoint

**POST** `/api/v1/members/search`

**Base URL (producción):**
`https://TU_DOMINIO`

**Ejemplo URL completa:**
`https://TU_DOMINIO/api/v1/members/search`

---

## Autenticación

Se requiere una API key **en headers**.

### Opción A (recomendada)
`X-API-KEY: <API_KEY>`

### Opción B (alternativa)
`Authorization: Bearer <API_KEY>`

---

## Headers requeridos

- `Content-Type: application/json`
- `Accept: application/json`
- `X-API-KEY: <API_KEY>` (o `Authorization: Bearer <API_KEY>`)

---

## Request body (dos formatos)

### A) Nombre completo (`name`)
Usa este formato para evitar problemas con apellidos compuestos.

Request:
{"name":"Hernán Bermúdez Requena"}

### B) Nombre segmentado
Este formato es útil si el cliente ya tiene el nombre separado.

Request:
{"firstname":"Hernán","lastname1":"Bermúdez","lastname2":"Requena"}

---

## Campo `homo_score`

- Si se usa el formato segmentado y NO se envía `homo_score`, el servidor lo calcula automáticamente.
- Si se usa el formato `name`, el servidor NO calcula `homo_score` (se deja como `null` a menos que el cliente lo envíe).

---

## Response 200 (success)

Estructura:

- `request_id`: identificador único del request
- `status`: código numérico (200)
- `meta`: metadatos del request
- `request`: eco de los datos de entrada
- `query`: información sobre si se guardó la consulta
- `results`: resultados encontrados

Ejemplo:

{
  "request_id": "b05b1896-7656-4dc2-a6f9-6d84e6290768",
  "status": 200,
  "meta": {
    "searched_at": "2026-01-03T19:37:53Z",
    "plan":"básica",
    "limit":15,"used":10,
    "remaining":5
  },
  "request": {
    "name": "Hernán Bermúdez Requena",
    "homo_score": null
  },
  "query": {
    "saved": false,
    "id": null
  },
  "results": {
    "count": 1,
    "members": [
      {
        "id": 158591,
        "media_score": true,
        "firstname": "Hernán",
        "lastname1": "Bermúdez",
        "lastname2": "Requena",
        "alias": ["Comandante H", "El Abuelo"],
        "birthday": null,
        "fake_identities": [],
        "titles": [
        	{
	        	"legacy_id":"1649917",
	        	"type":"C1",
	        	"profesion":"LICENCIATURA EN DERECHO",
	        	"institution":"Universidad Nacional Autónoma De México","year":"1992"
	        }
        ],
        "classification": { "involved": true },
        "rolegroup": "Líder",
        "cartel": { "id": 2729, "name": "La Barredora" },
        "cartel_designation": {
          "status": "designated",
          "source": "parent",
          "name": "Cártel Jalisco Nueva Generación",
          "date": "2025-02-20",
          "relation": "subordinada a"
        },
        "notes": ["Se identificó el nombramiento para un cargo y adscripción con alta exposición al crimen organizado."],
        "appointments": [
        	{
        		"id":23,
        		"role":"Secretario de Seguridad",
        		"organization":"Gobierno de Tabasco",
        		"span_label":"17/05/2021 a 04/01/2022"
        	}
        ],
        "hits": [
        	{
        		"date":"2025-10-13",
        		"link":"https://www.onexpo.com.mx/NOTICIAS/EMPRESARIOS-IMPLICADOS-EN-HUACHICOL-FISCAL-MANTIEN_dMtK2/",
        		"county":"Tampico",
        		"state_shortname":"Tamps"
        	}
        ]
      }
    ]
  }
}

---

## Response 401 (Unauthorized)

Se devuelve cuando falta la API key o es inválida.

{"request_id":"...","status":401,"errors":[{"code":"unauthorized","message":"API key inválida o ausente."}]}

---

## Response 422 (Invalid Request)

Se devuelve cuando faltan campos obligatorios o son inválidos.

### Si se usa formato segmentado
{"request_id":"...","status":422,"errors":[{"code":"invalid_request","message":"Debes completar firstname, lastname1, lastname2 (>=2 chars)."}]}

### Si se usa formato `name`
{"request_id":"...","status":422,"errors":[{"code":"invalid_request","message":"Debes completar name (>=4 chars)."}]}

---

## Ejemplos curl

### A) Nombre completo (`name`)
curl -s -X POST "https://TU_DOMINIO/api/v1/members/search" -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-KEY: TU_API_KEY" -d '{"name":"Hernán Bermúdez Requena"}'

### B) Nombre segmentado
curl -s -X POST "https://TU_DOMINIO/api/v1/members/search" -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-KEY: TU_API_KEY" -d '{"firstname":"Hernán","lastname1":"Bermúdez","lastname2":"Requena"}'

### C) Sin API key (genera 401)
curl -s -X POST "https://TU_DOMINIO/api/v1/members/search" -H "Content-Type: application/json" -H "Accept: application/json" -d '{"name":"Hernán Bermúdez Requena"}'

---
