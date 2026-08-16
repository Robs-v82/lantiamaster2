require 'csv'

class AgentController < ApplicationController
  before_action :authenticate_terrorist_access

  # ── Serper queries (DETENTIONS) ───────────────────────────────────────────
  SERPER_QUERIES = [
    "detienen líder cártel México",
    "capturan integrantes CJNG México operativo",
    "cae líder criminal célula México",
    "detenido integrante cártel Sinaloa",
    "caen integrantes crimen organizado México",
    "operativo detienen célula criminal México"
  ].freeze

  # ── Serper queries (CRIMINAL MEMBERS) ──────────────────────────────────────
  # Notas:
  # - Queries temáticas: ELIMINA toda mención de detenidos/capturas/procesamientos
  # - Queries por organización: INCLUYE TODAS las 11 del dailySearchScript
  # - Total: 21 queries
  SERPER_QUERIES_CRIMINAL_MEMBERS = [
    # ── Queries temáticas: Empresarios/Civiles (sin detención) ──────
    "empresario narco México vínculos",
    "empresario lavador dinero México",
    "prestanombres crimen organizado México",
    "traficante dinero cartel México",

    # ── Queries temáticas: Funcionarios/Autoridades (sin detención) ──
    "alcalde vínculos crimen organizado México",
    "funcionario corrupción narcotráfico México",
    "gobernador vínculos cártel México",
    "policía corrupción crimen organizado",

    # ── Queries temáticas: Dinero/Activos ────────────────────────────
    "dinero narcotráfico decomiso México",
    "bienes incautados crimen organizado",
    "operación financiera narcos México",

    # ── Queries por organizaciones (TODAS del dailySearchScript) ──────
    # 11 organizaciones:
    "cartel México",                          # 1. cartel (genérico)
    "Cártel Jalisco Nueva Generación",        # 2. Cártel Jalisco
    "Cártel de Sinaloa",                      # 3. Cártel de Sinaloa
    "Mayiza México",                          # 4. Mayiza
    "Chapitos México",                        # 5. Chapitos
    "CJNG México",                            # 6. CJNG
    "Cárteles Unidos México",                 # 7. Cárteles Unidos
    "Cártel del Noreste",                     # 8. Cártel del Noreste
    "Familia Michoacana México",              # 9. Familia Michoacana
    "huachicol México",                       # 10. huachicol
    "cobro de cuota México"                   # 11. cobro de cuota
  ].freeze

  # ── Extraction filters (DETENTIONS) ────────────────────────────────────────
  EXCLUDED_TITLE_WORDS   = %w[opinión opinion analisis análisis columna editorial].freeze

  # ── Extraction filters (CRIMINAL MEMBERS) ──────────────────────────────────
  EXCLUDED_TITLE_WORDS_CRIMINAL = [].freeze
  REQUIRED_SNIPPET_WORDS = %w[deteni captur abati arrest operativo asegurado asegura
                               aprehend imputad bloqueo narco cjng cartel cártel
                               elementos seguridad militares sedena fuerzas].freeze
  THEFT_WORDS            = %w[ladrón ladron autopartes].freeze
  THEFT_PHRASES          = ["robo de vehículo", "robo de vehiculo"].freeze
  CRIMEN_WORDS           = ["crimen organizado", "cartel", "cártel"].freeze
  EXCLUDED_DOMAINS       = %w[facebook.com].freeze
  EXCLUDED_DOMAINS_CRIMINAL = %w[facebook.com twitter.com].freeze

  # ── Claude system prompt ──────────────────────────────────────────────────
  # ── Deduplication prompt ──────────────────────────────────────────────
  DEDUPLICATION_PROMPT = <<~PROMPT.strip.freeze
    ⚠️ RESPONDE ÚNICAMENTE CON JSON. NADA MÁS. SIN ANÁLISIS, SIN EXPLICACIONES.

    Tu tarea: agrupar artículos por tema/evento.

    Entrada: lista numerada de títulos.
    Salida: JSON válido.

    Estructura exacta del JSON:
    {
      "groups": [
        {
          "theme": "Nombre corto del tema",
          "indices": [0, 1, 5, 12]
        }
      ]
    }

    Reglas de agrupación:
    - "El Gabito Mazatlán" = UN evento (aunque 20 medios lo cubran)
    - "CJNG túnel fronterizo" = OTRO evento diferente
    - "Investigación transportistas" = OTRO evento diferente
    - Los índices son posición 0-based de la lista original

    CRÍTICO: Devuelve SOLO el JSON válido. Nada antes, nada después.
  PROMPT

  # ── Claude system prompt ──────────────────────────────────────────────
  EXTRACTION_SYSTEM_PROMPT = <<~PROMPT.strip.freeze
    ⚠️ ⚠️ ⚠️ INSTRUCCIÓN CRÍTICA ABSOLUTA ⚠️ ⚠️ ⚠️
    TU RESPUESTA DEBE SER ÚNICAMENTE UNO DE ESTOS CASOS:

    CASO 1: Si la nota describe detenidos/abatimientos concretos que califican:
      - Emite SOLO las líneas CSV (una por línea)
      - Nada más. Ni análisis, ni explicaciones, ni razonamiento, ni introducción, ni conclusión.

    CASO 2: Si la nota NO califica o no hay operativo concreto:
      - Responde ÚNICAMENTE la palabra: DESCARTAR
      - Una palabra. Nada más.

    EJEMPLOS DE LO QUE ESTÁ PROHIBIDO (respuestas INCORRECTAS):
      ❌ "Analizando la nota...después del análisis, los datos son..."
      ❌ "Basándome en el contenido, encuentro..."
      ❌ "La nota menciona 3 detenidos, por lo que extraigo..."
      ❌ "Según el artículo, los datos son: 01,01,26,Estado,12001,Municipio,1,3..."
      ❌ Cualquier palabra antes del CSV
      ❌ Cualquier palabra después del CSV
      ❌ Múltiples oraciones o párrafos

    RESPUESTAS CORRECTAS:
      ✓ 01,01,26,Ciudad de México,09009,Iztapalapa,1,3,CJNG,...,URL
      ✓ 02,02,26,Sinaloa,25006,Culiacán,1,2,...
      ✓ DESCARTAR

    Eres un agente especializado en extraer información estructurada de notas periodísticas sobre operativos de seguridad en México.

    ⚠️ INSTRUCCIÓN CRÍTICA: Responde SOLO con las líneas CSV. NO escribas análisis, razonamiento, explicaciones, ni comentarios antes o después del CSV. Si la nota no califica, responde ÚNICAMENTE: DESCARTAR

    ⚠️ ⚠️ ⚠️ FORMATO OBLIGATORIO CON CITAS TEXTUALES ⚠️ ⚠️ ⚠️

    ESTO NO ES NEGOCIABLE. SIGUE ESTO AL PIE DE LA LETRA O TU RESPUESTA SERÁ RECHAZADA.

    FORMATO DE RESPUESTA OBLIGATORIO - CITAS SEPARADAS:

    Primero: BLOQUE DE CITAS (líneas que comienzan con ###CITA)
    Luego: LÍNEAS CSV NORMALES (sin citas incrustadas)

    ESTRUCTURA EXACTA REQUERIDA:
    ###CITA campo_número "cita textual extraída directamente del artículo"
    ###CITA campo_número "otra cita textual"
    ... más citas ...
    1,06,26,Sinaloa,25006,Culiacán,,...,URL

    EJEMPLO CORRECTO (ESTE ES EL ÚNICO FORMATO ACEPTADO):
    ###CITA 3 "1 de junio de 2026"
    ###CITA 5 "estado de Sinaloa"
    ###CITA 6 "municipio de Culiacán"
    ###CITA 11 "Gabriel Martínez fue detenido"
    ###CITA 16 "de 37 años"
    1,06,26,Sinaloa,25006,Culiacán,,,,,Gabriel,Martínez,,,M,37,,...,URL

    SI NO EXISTE CITA TEXTUAL PARA UN CAMPO:
    ✓ NO ESCRIBAS ###CITA para ese campo
    ✓ DEJA ESE CAMPO VACÍO en el CSV
    ✓ Ejemplo: Si no aparece edad → no escribas ###CITA 16 y deja campo 16 vacío

    VALIDACIÓN BACKEND - SE EJECUTARÁ AUTOMÁTICAMENTE:
    El sistema buscará CADA cita (###CITA) dentro del texto original del artículo.
    • CITA ENCONTRADA → Campo se acepta con su valor
    • CITA NO ENCONTRADA → Campo se marca VACÍO, se registra en log
    • SIN ###CITA PARA VALOR → Campo se marca VACÍO, se registra en log

    LOG INCLUIRÁ LÍNEAS COMO:
    [CITA_VALIDADA] Campo 3 "1 de junio de 2026" → ACEPTADA
    [CITA_FALLIDA] Campo 16 - No se encontró cita en el texto → Campo = VACÍO
    [CITA_FALTANTE] Campo 11 - Sin ###CITA pero hay valor → Campo = VACÍO

    CUALQUIER VIOLACIÓN RECHAZA LA RESPUESTA:
    ❌ Responder CSV sin bloque ###CITA
    ❌ Incluir ###CITA con texto que NO aparece en el artículo
    ❌ Tener valor en CSV pero NO incluir ###CITA correspondiente
    ❌ Escribir análisis, explicaciones, narrativa o razonamiento
    ❌ "Probablemente", "parece que", "basándome en"

    Recibes el texto completo de una nota. Tu tarea es extraer los datos y devolverlos como UNA o VARIAS líneas CSV según las reglas siguientes.

    AÑO EN CURSO: 2026 (dos dígitos: 26). Para el campo Año usa siempre los dos últimos dígitos del año real del evento: 2026 → 26, 2025 → 25. Si la nota no indica fecha exacta del operativo, usa la fecha de publicación de la nota. Nunca uses 25 para un evento que ocurrió en 2026.

    REGLA ANTI-DUPLICADOS INTRA-NOTA:
    Un operativo mencionado más de una vez dentro de la misma página (en el cuerpo, en tweets embebidos, en notas relacionadas o en cualquier otro bloque) cuenta como UNA SOLA fila. No generes filas adicionales por repeticiones del mismo evento.

    REGLAS DE FILAS:
    - Una fila por cada persona detenida o abatida identificada por nombre
    - Si hay N personas sin nombre individual pero sí un total grupal, emite UNA sola fila con Detenidos=N y campos de nombre vacíos
    - Si hay mezcla (2 identificados + 3 anónimos): 2 filas individuales + 1 fila grupal con Detenidos=3

    CRITERIO DE ALTO IMPACTO (obligatorio):
    Descarta la nota y responde DESCARTAR si se cumplen las dos condiciones siguientes:
    - La persona detenida no tiene un cargo de liderazgo identificado
    - El número de detenidos es menor a 3

    COLUMNAS (en este orden exacto, separadas por coma):
    1. Día (entero, sin cero inicial)
    2. Mes (entero con cero inicial si <10)
    3. Año (2 dígitos)
    4. Estado (nombre completo de la entidad federativa)
    5. full_code (código municipal de la base de datos — NO lo generes, dejar VACÍO si no se identifica municipio)
    6. Municipio (nombre)
    7. Abatido (1 si hubo abatido, vacío si no)
    8. Detenidos (entero >= 1; si solo hubo abatimientos sin detenidos, pon 0)
    9. Organización (cártel de nivel superior)
    10. Grupo afiliado (nombre exacto del catálogo que se te proporciona)
    11. Nombre (primer nombre, vacío si desconocido)
    12. Apellido Paterno (vacío si desconocido)
    13. Apellido Materno (vacío si desconocido)
    14. Alias (separados por punto y coma, vacío si no hay)
    15. Género (M o F, vacío si no se menciona)
    16. Edad (entero, vacío si no se menciona)
    17. Posición liderazgo (1 si es líder o jefe, vacío si no)
    18. Rol (valor exacto del catálogo — ver abajo)
    19. SEDENA (1 si participó, vacío si no)
    20. SEMAR (1 si participó, vacío si no)
    21. GN (1 si participó, vacío si no)
    22. SSCP (1 si participó, vacío si no)
    23. FGR (1 si participó, vacío si no)
    24. SSP-Estatal (1 si participó, vacío si no)
    25. FGE/PGJ (1 si participó, vacío si no)
    26. Policía municipal (1 si participó, vacío si no)
    27. Otro (1 si participó alguna fuerza no listada, vacío si no)
    28. Fuente (URL completa de la nota)

    CAMPOS OBLIGATORIOS — nunca deben quedar vacíos:
    - Detenidos: si no se menciona número exacto pero hay al menos una persona detenida, pon 1
    - Fuente: siempre la URL completa de la nota
    - Rol: siempre un valor exacto del catálogo. Si no se puede determinar, usa "Otro"

    CATÁLOGO DE ROL — únicos valores permitidos, exactamente como aparecen aquí:
    Extorsionador | Sicario | Líder | Autoridad cooptada | Jefe de célula | Jefe de plaza | Jefe de sicarios | Jefe operativo | Jefe regional | Narcomenudista | Traficante o distribuidor | Otro
    Nunca uses un valor fuera de este catálogo. Si el rol no está claro, usa "Otro".

    ORGANIZACIÓN Y GRUPO AFILIADO — interpretación activa:
    Normaliza cualquier variante, sigla, apodo o nombre alternativo al valor exacto del catálogo. Ejemplos obligatorios:
    - "CJNG", "Jalisco", "Mencho", "Fuerzas Especiales Mencho" → match en catálogo
    - "Los Chapitos", "facción Guzmán", "Los Guzmán" → "Cártel de Sinaloa (Los Guzmán)"
    - "Mayo Zambada", "Los Mayos", "facción Zambada" → "Cártel de Sinaloa (Los Zambada)"
    - "CDN", "Noreste" → match en catálogo
    Si después del intento de normalización no encuentras ningún match, escribe "No identificada" — nunca dejes estos campos vacíos.

    MUNICIPIO Y FULL_CODE — búsqueda en base de datos:

    Columna 5. full_code (código municipal completo de la BD — NUNCA lo generes ni adivines)
    Columna 6. Municipio (nombre del municipio mencionado en la nota)

    INSTRUCCIONES CRÍTICAS:
    - Extrae del texto el NOMBRE del municipio y estado con máxima precisión
    - NUNCA intentes generar, calcular o adivinar el full_code
    - Si NO puedes identificar el municipio con certeza desde el texto de la nota, deja el campo municipio VACÍO (el full_code será vacío también)
    - Si el municipio usa un alias común (ej: "Los Mochis" en lugar de "Ahome", "Cancún" en lugar de "Benito Juárez"), extrae el nombre que aparece en la nota tal cual está escrito
    - Si la nota menciona múltiples ubicaciones, extrae la ciudad/municipio donde ocurrió el operativo de detención, no donde fue publicada la nota

    BÚSQUEDA EN BACKEND (NO ES TU RESPONSABILIDAD):
    El sistema backend buscará automáticamente en la base de datos por estos pasos:
    1. Busca por estado + nombre exacto del municipio
    2. Busca por estado + nombre normalizado (sin acentos, minúsculas)
    3. Busca por estado + alias del municipio (tabla county_aliases)
    4. Si encuentra match: captura el full_code
    5. Si NO encuentra match: full_code queda vacío

    El backend registrará en el log exactamente QUÉ query hizo y QUÉ resultado obtuvo.

    REGLAS CRÍTICAS:
    - Si la nota NO describe una detención o abatimiento concreto y confirmado, responde únicamente con: DESCARTAR
    - No inventes datos. Si algo no está en la nota, deja la celda vacía
    - Edad: SOLO completa este campo si el texto menciona explícitamente un número de años de la persona detenida o abatida (ej. "de 34 años", "tiene 28 años"). Descripción física, apariencia o contexto NO son fuente válida para inferir edad. Si no hay número explícito, deja vacío.
    - Usa la fecha del operativo, no la de publicación. Si no hay fecha exacta, usa la de publicación
    - Nombres en Title Case
    - El alias usa punto y coma como separador interno
    - Para fuerzas: solo pon 1 si la nota las menciona explícitamente. Nunca inferir
    - Si la nota dice "elementos de seguridad" sin especificar fuerza, usa Otro=1

    VALIDACIÓN Y AUTO-CORRECCIÓN OBLIGATORIA:
    Antes de emitir cada fila CSV, VALIDA que cumpla EXACTAMENTE:
    1. Exactamente 28 campos (separados por coma)
    2. Campos numéricos [0,1,2,4,6,7,15,16,17,18,19,20,21,22,23,24,25,26] contienen SOLO números o están VACÍOS
       (nunca deben contener texto)
    3. Campo Rol (posición 18) NUNCA está vacío - si no identificas rol claro, usa "Otro"
    4. Campo Fuente (posición 28) es una URL válida
    5. Todo campo de texto que contenga comas está entre comillas dobles

    PROCEDIMIENTO SI LA VALIDACIÓN FALLA:
    - NO omitas la fila
    - Reescribe la fila COMPLETA corrigiendo todos los errores
    - Valida nuevamente
    - REPITE hasta que la fila cumpla TODOS los criterios anteriores
    - Solo entonces continúa con el siguiente artículo

    Ejemplo: Si generaste "Sicario" en el campo SEDENA (col 19), reescribe la fila entera
    moviendo "Sicario" al campo Rol (col 18) y dejando SEDENA vacío.
  PROMPT

  # ── Claude system prompt (CRIMINAL MEMBERS) ────────────────────────────────
  EXTRACTION_SYSTEM_PROMPT_CRIMINAL_MEMBERS = <<~PROMPT.strip.freeze
    ⚠️ ⚠️ ⚠️ INSTRUCCIÓN CRÍTICA ABSOLUTA ⚠️ ⚠️ ⚠️

    Eres especialista en extraer información sobre PERSONAS VINCULADAS
    a crimen organizado desde artículos periodísticos mexicanos.

    TU RESPUESTA DEBE SER ÚNICAMENTE UNO DE ESTOS CASOS:

    CASO 1: Si el artículo describe una PERSONA con UN SEÑALAMIENTO
            CONCRETO de vínculos a crimen organizado:
      - Emite SOLO las líneas CSV (una por línea)
      - Nada más. Ni análisis, ni explicaciones, ni razonamiento.

      ✓ SEÑALAMIENTOS CONCRETOS válidos:
        - "Fue detenido por presuntos vínculos a CJNG"
        - "Le secuestraron equipos de comunicación de narcos"
        - "Es operador de dinero para Cártel de Sinaloa"
        - "Procesado por enriquecimiento ilícito del narcotráfico"
        - "Empresa es prestanombres de cartel"
        - "Alcalde con vínculos comprobados a organización criminal"

    CASO 2: Si el artículo NO describe una persona específica O
            NO hay señalamiento concreto de vínculos:
      - Responde ÚNICAMENTE: DESCARTAR
      - Una palabra. Nada más.

      ❌ NO CALIFICA:
        - "El narco es un problema en México" (sin persona específica)
        - "Empresario donó a fundación" (sin vínculo concreto)
        - "Presuntamente podría estar vinculado" (demasiado especulativo)
        - "Se investiga a persona X" (sin señalamiento concreto)

    EJEMPLOS DE LO QUE ESTÁ PROHIBIDO (respuestas INCORRECTAS):
      ❌ "Analizando el artículo...después del análisis, los datos son..."
      ❌ "Basándome en el contenido, encuentro..."
      ❌ "El artículo menciona a Juan García, por lo que extraigo..."
      ❌ Cualquier palabra antes del CSV
      ❌ Cualquier palabra después del CSV
      ❌ Múltiples oraciones o párrafos

    RESPUESTAS CORRECTAS:
      ✓ Juan,García,López,Empresario,CJNG,Guadalajara,30,M,...,URL
      ✓ María,Rodríguez,Pérez,Alcalde,Sinaloa,Culiacán,...,URL
      ✓ DESCARTAR

    FORMATO OBLIGATORIO CON CITAS TEXTUALES:

    Primero: BLOQUE DE CITAS (líneas que comienzan con ###CITA)
    Luego: LÍNEAS CSV NORMALES (sin citas incrustadas)

    ESTRUCTURA EXACTA REQUERIDA:
    ###CITA nombre "Juan García López"
    ###CITA ocupacion "empresario de Guadalajara"
    ###CITA vinculo "vínculos con CJNG"
    Juan,García,López,Empresario,CJNG,Guadalajara,30,M,...,URL

    SI NO EXISTE CITA TEXTUAL PARA UN CAMPO:
    ✓ NO ESCRIBAS ###CITA para ese campo
    ✓ DEJA ESE CAMPO VACÍO en el CSV
    ✓ Ejemplo: Si no aparece edad → no escribas ###CITA edad y deja campo vacío

    VALIDACIÓN BACKEND - SE EJECUTARÁ AUTOMÁTICAMENTE:
    El sistema buscará CADA cita (###CITA) dentro del texto original del artículo.
    • CITA ENCONTRADA → Campo se acepta con su valor
    • CITA NO ENCONTRADA → Campo se marca VACÍO, se registra en log
    • SIN ###CITA PARA VALOR → Campo se marca VACÍO, se registra en log

    ESTRUCTURA DE CAMPOS CSV (13 campos):
    1. Nombre
    2. Apellido Paterno
    3. Apellido Materno
    4. Ocupación/Rol
    5. Organización
    6. Estado/Ciudad
    7. Edad
    8. Género (M/F/X)
    9. Tipo de vínculo (Operador/Empresario/Funcionario/Narco/Otro)
    10. Documento/Acusación
    11. Fecha del señalamiento (si está disponible)
    12. Fuente (URL)
    13. Notas adicionales

    REGLAS CRÍTICAS:
    - Si la nota NO describe una persona específica o no hay señalamiento concreto, responde ÚNICAMENTE: DESCARTAR
    - No inventes datos. Si algo no está en la nota, deja la celda vacía
    - Edad: SOLO completa si el texto menciona explícitamente un número (ej. "de 34 años", "tiene 28 años")
    - Nombres en Title Case
    - Ocupación: valores del catálogo si aplica, o descripción genérica (Empresario, Narco, Funcionario, Operador, Otro)
    - Organización: nombre exacto de la organización criminal mencionada. Si no está claro, usa "No identificada"
    - Tipo de vínculo: cómo se vincula a crimen organizado (Operador, Empresario, Funcionario, Narco, Otro)
    - Documento/Acusación: qué tipo de documento o acusación (Detenido, Procesado, Imputado, Investigado, Decomiso, Etc)
    - URL: siempre la URL completa de la nota
  PROMPT

  # ═══════════════════════════════════════════════════════════════════════════
  # ACTIONS
  # ═══════════════════════════════════════════════════════════════════════════

  def detentions
  end

  def criminal_members
  end

  def search
    api_key = serper_api_key
    return render json: { error: "SERPER_API_KEY no configurada." }, status: :service_unavailable if api_key.blank?

    results = []
    mutex   = Mutex.new

    threads = SERPER_QUERIES.map do |query|
      Thread.new do
        begin
          uri  = URI("https://google.serper.dev/news")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl      = true
          http.read_timeout = 10
          http.open_timeout = 5

          req = Net::HTTP::Post.new(uri)
          req["X-API-KEY"]    = api_key
          req["Content-Type"] = "application/json"
          req.body = { q: query, tbs: "qdr:d", gl: "mx", hl: "es", num: 10 }.to_json

          res  = http.request(req)
          data = JSON.parse(res.body)
          mutex.synchronize { results.concat(data["news"]) } if data["news"].is_a?(Array)
        rescue => e
          Rails.logger.error("[Agent#search] #{query.inspect} #{e.class}: #{e.message}")
        end
      end
    end

    threads.each(&:join)

    seen   = {}
    unique = results.select { |a| a["link"] && seen[a["link"]] ? false : (seen[a["link"]] = true) }
    render json: { articles: unique }
  end

  def search_criminal_members
    api_key = serper_api_key
    return render json: { error: "SERPER_API_KEY no configurada." }, status: :service_unavailable if api_key.blank?

    results = []
    mutex   = Mutex.new

    threads = SERPER_QUERIES_CRIMINAL_MEMBERS.map do |query|
      Thread.new do
        begin
          uri  = URI("https://google.serper.dev/news")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl      = true
          http.read_timeout = 10
          http.open_timeout = 5

          req = Net::HTTP::Post.new(uri)
          req["X-API-KEY"]    = api_key
          req["Content-Type"] = "application/json"
          req.body = { q: query, tbs: "qdr:d", gl: "mx", hl: "es", num: 10 }.to_json

          res  = http.request(req)
          data = JSON.parse(res.body)
          mutex.synchronize { results.concat(data["news"]) } if data["news"].is_a?(Array)
        rescue => e
          Rails.logger.error("[Agent#search_criminal_members] #{query.inspect} #{e.class}: #{e.message}")
        end
      end
    end

    threads.each(&:join)

    seen   = {}
    unique = results.select { |a| a["link"] && seen[a["link"]] ? false : (seen[a["link"]] = true) }
    render json: { articles: unique }
  end

  def deduplicate
    body     = JSON.parse(request.raw_post)
    articles = (body["articles"] || []).map(&:to_h)
    return render json: { error: "No articles provided" }, status: :bad_request if articles.blank?

    claude_key = anthropic_api_key
    return render json: { error: "ANTHROPIC_API_KEY no configurada." }, status: :service_unavailable if claude_key.blank?

    # Build list of titles for Claude
    titles_list = articles.map.with_index { |a, i| "#{i}: #{a['title']}" }.join("\n")
    user_message = "Agrupa estos #{articles.length} artículos por tema/evento:\n\n#{titles_list}"

    # Call Claude to group articles
    uri  = URI("https://api.anthropic.com/v1/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = true
    http.read_timeout = 30
    http.open_timeout = 10

    req = Net::HTTP::Post.new(uri)
    req["x-api-key"]         = claude_key
    req["anthropic-version"] = "2023-06-01"
    req["content-type"]      = "application/json"
    req.body = {
      model:       "claude-sonnet-4-6",
      max_tokens:  1024,
      temperature: 0.0,
      system:      DEDUPLICATION_PROMPT,
      messages:    [{ role: "user", content: user_message }]
    }.to_json

    res  = http.request(req)
    body = JSON.parse(res.body)
    response_text = body.dig("content", 0, "text")

    if response_text.blank?
      return render json: { error: "Claude did not respond" }, status: :service_unavailable
    end

    # Parse JSON from Claude
    begin
      # Clean up response: remove markdown code blocks if present
      cleaned_response = response_text.gsub(/^```json\n?/, '').gsub(/\n?```$/, '').strip

      grouping = JSON.parse(cleaned_response)
      groups = (grouping["groups"] || []).map do |g|
        {
          theme: g["theme"],
          articles: (g["indices"] || []).map { |idx| articles[idx] }
        }
      end
      render json: { groups: groups }
    rescue JSON::ParserError => e
      Rails.logger.error("[Agent#deduplicate] JSON parse error: #{e.message}")
      Rails.logger.error("[Agent#deduplicate] Claude response (first 500 chars): #{response_text.first(500)}")
      render json: { error: "Failed to parse grouping: #{e.message}" }, status: :service_unavailable
    end
  end

  def extract_url
    body  = JSON.parse(request.raw_post)
    url   = body["url"].to_s.strip
    return render json: { error: "URL vacía" }, status: :bad_request if url.blank?

    claude_key = anthropic_api_key
    return render json: { error: "ANTHROPIC_API_KEY no configurada." }, status: :service_unavailable if claude_key.blank?

    organizations = criminal_organizations
    result = process_single_article(
      { "url" => url, "title" => "", "snippet" => "" },
      organizations,
      claude_key
    )
    render json: { results: [result] }
  end

  def diagnose
    report = {}

    # 1. Anthropic key
    key = anthropic_api_key
    report[:anthropic_key_found] = key.present?
    report[:anthropic_key_source] =
      if ENV["ANTHROPIC_API_KEY"].present? then "ENV"
      elsif Rails.application.credentials.dig(:anthropic, :api_key).present? then "credentials"
      else
        kf = Rails.root.join("..", "..", "shared", "config", "anthropic_api_key").expand_path
        File.exist?(kf) ? "file (#{kf})" : "NOT FOUND"
      end

    if key.present?
      # 2. Test call to Claude
      begin
        uri  = URI("https://api.anthropic.com/v1/messages")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 20
        http.open_timeout = 10

        req = Net::HTTP::Post.new(uri)
        req["x-api-key"]         = key
        req["anthropic-version"] = "2023-06-01"
        req["content-type"]      = "application/json"
        req.body = {
          model:      "claude-sonnet-4-6",
          max_tokens: 16,
          messages:   [{ role: "user", content: "Responde solo: OK" }]
        }.to_json

        res  = http.request(req)
        body = JSON.parse(res.body)

        report[:claude_http_status]  = res.code.to_i
        report[:claude_response_ok]  = body.dig("content", 0, "text").present?
        report[:claude_text]         = body.dig("content", 0, "text")
        report[:claude_error]        = body["error"]
      rescue => e
        report[:claude_exception] = "#{e.class}: #{e.message}"
      end
    end

    render json: report
  end

  def extract_batch
    body          = JSON.parse(request.raw_post)
    articles      = (body["articles"] || []).map(&:to_h)
    organizations = criminal_organizations

    claude_key = anthropic_api_key
    return render json: { error: "ANTHROPIC_API_KEY no configurada." }, status: :service_unavailable if claude_key.blank?

    results = articles.map do |article|
      result = process_single_article(article, organizations, claude_key)

      # Guardar CSV rows en detention_captures
      if result[:status] == "ok" && result[:csv_rows].present?
        url = article["url"].to_s
        estado = result[:full_code_lookups]&.first&.dig(:estado)
        municipio = result[:full_code_lookups]&.first&.dig(:municipio)

        result[:save_results] = result[:csv_rows].map do |csv_row|
          save_csv_row_to_db(csv_row, url, estado, municipio, nil)
        end
      end

      result
    end

    # LOGUEAR RESUMEN FINAL
    summary = results.group_by { |r| r[:status] }
    Rails.logger.info(
      "[Agent#extract_batch] RESUMEN FINAL | " +
      "Total artículos: #{results.length} | " +
      "OK: #{summary['ok']&.length || 0} | " +
      "Discarded: #{summary['discarded']&.length || 0} | " +
      "Error: #{summary['error']&.length || 0}"
    )

    # Loguear detalles de cada resultado de guardado
    results.each do |result|
      if result[:save_results]&.any?
        result[:save_results].each do |save_result|
          Rails.logger.info(
            "[Agent#extract_batch] #{result[:url]} | " +
            "Save result: #{save_result[:status]} | " +
            "Reason: #{save_result[:reason]}"
          )
        end
      end
    end

    render json: { results: results }
  end

  def process_single_article(article, organizations, claude_key)
    url     = article["url"].to_s
    title   = article["title"].to_s
    snippet = article["snippet"].to_s

    # Verificación previa: ¿URL ya fue procesado?
    existing = DetentionCapture.where(source_url: url).limit(1).first
    if existing.present?
      return { url: url, status: "skipped", reason: "url_already_processed", id: existing.id }
    end

    # Filter 0: excluded domains
    if EXCLUDED_DOMAINS.any? { |d| url.include?(d) }
      return { url: url, status: "discarded", reason: "snippet_irrelevante", csv_rows: [], content_length: 0 }
    end

    # Filter 1: excluded title keywords
    title_lower = I18n.transliterate(title.downcase)
    if EXCLUDED_TITLE_WORDS.any? { |w| title_lower.include?(w) }
      return { url: url, status: "discarded", reason: "titulo_excluido", csv_rows: [], content_length: 0 }
    end

    # Filter 2 (snippet keywords requeridas): ELIMINADO — demasiadas notas válidas excluidas

    # Filter 3: theft content without organized-crime context
    snippet_lower = I18n.transliterate(snippet.downcase)
    is_theft = THEFT_WORDS.any? { |w| snippet_lower.include?(w) } ||
               THEFT_PHRASES.any? { |p| snippet_lower.include?(p) }
    if is_theft && CRIMEN_WORDS.none? { |w| snippet_lower.include?(w) }
      return { url: url, status: "discarded", reason: "snippet_irrelevante", csv_rows: [], content_length: 0 }
    end

    # Fetch article content
    content = fetch_article_content(url)
    if content.blank?
      return { url: url, status: "discarded", reason: "fetch_error", csv_rows: [], content_length: 0, fetch_error_detail: "Empty content" }
    end

    content_length = content.length

    # Call Claude
    claude_response = call_claude_api(content, url, organizations, claude_key)

    # LOGUEAR RESPUESTA COMPLETA DE CLAUDE
    Rails.logger.info(
      "[Agent#claude_response] #{url} | " +
      "Respuesta Claude (#{claude_response&.length || 0} chars):\n#{claude_response&.to_s&.first(2000)}"
    )

    # Handle error response from Claude API
    if claude_response.is_a?(Hash) && claude_response[:error]
      return { url: url, status: "error", reason: "claude_error", csv_rows: [], error_detail: claude_response[:error], content_length: content_length }
    end

    if claude_response.nil?
      return { url: url, status: "error", reason: "claude_error", csv_rows: [], content_length: content_length }
    end

    if claude_response.strip =~ /\ADESCARTAR\b/i
      return { url: url, status: "discarded", reason: "claude_descartar", csv_rows: [], content_length: content_length }
    end

    # Extract and validate citations (###CITA lines)
    citation_lines = claude_response.strip.split("\n").select { |l| l.match?(/^###CITA\s+\d+\s+/) }
    citations = {}
    citation_validations = []

    citation_lines.each do |line|
      if line.match(/^###CITA\s+(\d+)\s+"(.+)"$/)
        field_num = $1.to_i
        citation_text = $2

        # Validate citation exists in article content
        citation_found = content.include?(citation_text)
        citations[field_num] = {
          text: citation_text,
          found: citation_found
        }

        status = citation_found ? "VÁLIDA" : "NO_ENCONTRADA"
        citation_validations << {
          field: field_num,
          citation: citation_text,
          status: status
        }
      end
    end

    # Parse CSV rows: must start with 1-2 digits (Día), have ≥27 commas, no markdown
    all_candidate_rows = claude_response.strip.split("\n")
                                       .map(&:strip)
                                       .reject(&:empty?)
                                       .reject { |r| r.start_with?("#", "*", "-", " ") }
                                       .reject { |r| r.start_with?("###CITA") }

    rows = all_candidate_rows.select { |r| r.match?(/\A\d{1,2},\d/) && r.count(",") >= 27 }
    invalid_rows = all_candidate_rows - rows

    # LOGUEAR FILAS INVÁLIDAS Y INTENTAR CORRECCIÓN
    corrected_rows = []
    invalid_rows.each do |row|
      validation = validate_csv_row_format(row)
      fields = row.split(",")
      estado = fields[3] rescue nil
      municipio = fields[5] rescue nil

      Rails.logger.warn(
        "[Agent#extract_batch] #{url} | ❌ FILA RECHAZADA (INTENTO 1) | " +
        "Razón: #{validation[:error_type]} | Detalles: #{validation[:details]} | " +
        "Estado: #{estado} | Municipio: #{municipio} | " +
        "Row preview: #{row.first(100)}"
      )

      # INTENTO DE CORRECCIÓN: Detectar si es solucionable
      if %w[campos_insuficientes formato_fecha_invalido url_invalida].include?(validation[:error_type])
        Rails.logger.info(
          "[Agent#extract_batch] #{url} | 🔄 INICIANDO REINTENTO DE CORRECCIÓN | " +
          "Tipo: #{validation[:error_type]} | Detalles: #{validation[:details]}"
        )

        correction_message = generate_correction_prompt(validation[:error_type], validation[:details])
        corrected_response = retry_claude_with_correction(
          content, url, correction_message, organizations, claude_key
        )

        if corrected_response.is_a?(Hash) && corrected_response[:error]
          Rails.logger.warn(
            "[Agent#extract_batch] #{url} | ❌ REINTENTO FALLÓ | " +
            "Error: #{corrected_response[:error]}"
          )
        else
          # Procesar la respuesta corregida
          corrected_lines = corrected_response.strip.split("\n")
                                              .map(&:strip)
                                              .reject(&:empty?)
                                              .reject { |r| r.start_with?("#", "*", "-", " ") }
                                              .reject { |r| r.start_with?("###CITA") }

          corrected_valid = corrected_lines.select { |r| r.match?(/\A\d{1,2},\d/) && r.count(",") >= 27 }

          if corrected_valid.any?
            corrected_valid.each do |corrected_row|
              corrected_fields = corrected_row.split(",")
              corrected_estado = corrected_fields[3] rescue nil
              corrected_municipio = corrected_fields[5] rescue nil

              Rails.logger.info(
                "[Agent#extract_batch] #{url} | ✅ REINTENTO EXITOSO | " +
                "Fila corregida: Persona: #{corrected_fields[10..12].compact.join(' ')} | " +
                "Estado: #{corrected_estado} | Municipio: #{corrected_municipio} | " +
                "Campos: #{corrected_fields.length}"
              )

              corrected_rows << corrected_row
            end
          else
            Rails.logger.warn(
              "[Agent#extract_batch] #{url} | ⚠️ REINTENTO COMPLETADO PERO SIN FILAS VÁLIDAS | " +
              "Respuesta corregida no contiene filas CSV válidas"
            )
          end
        end
      else
        Rails.logger.warn(
          "[Agent#extract_batch] #{url} | ⚠️ ERROR NO SOLUCIONABLE | " +
          "Tipo: #{validation[:error_type]} - No se intenta reintento automático"
        )
      end
    end

    # Agregar filas corregidas a las válidas
    rows = rows + corrected_rows
    Rails.logger.info(
      "[Agent#extract_batch] #{url} | 📊 RESULTADO DE VALIDACIÓN | " +
      "Filas válidas iniciales: #{all_candidate_rows.select { |r| r.match?(/\A\d{1,2},\d/) && r.count(',') >= 27 }.length} | " +
      "Filas corregidas: #{corrected_rows.length} | " +
      "Total final: #{rows.length}"
    ) if corrected_rows.any?

    # Lookup full_code in database for each row
    rows_with_lookups = rows.map do |row|
      fields = row.split(",").map { |f| f.gsub(/^"(.*)"$/, '\1') }
      estado = fields[3] if fields.length > 3
      full_code_from_claude = fields[4] if fields.length > 4
      municipio = fields[5] if fields.length > 5

      # Try to find full_code via database lookup
      lookup_result = lookup_full_code(municipio, estado, url)

      # Replace field[4] with actual full_code from DB (or keep empty if not found)
      if lookup_result && lookup_result[:full_code]
        fields[4] = lookup_result[:full_code]
      else
        fields[4] = ""  # Leave empty if DB lookup fails
      end

      new_row = fields.map { |f| f.to_s.include?(",") ? "\"#{f}\"" : f }.join(",")

      {
        row: new_row,
        original_full_code: full_code_from_claude,
        municipio: municipio,
        estado: estado,
        lookup: lookup_result
      }
    end

    # When no rows parsed, include a truncated Claude response for diagnosis
    debug = rows.empty? ? claude_response.strip.first(1000) : nil

    final_csv_rows = rows_with_lookups.map { |r| r[:row] }

    # LOGUEAR CSV ROWS QUE SE DEVOLVERÁN AL CLIENTE
    if final_csv_rows.any?
      Rails.logger.info(
        "[Agent#csv_rows_output] #{url} | " +
        "Devolviendo #{final_csv_rows.length} fila(s) al cliente:\n" +
        final_csv_rows.map { |row| "  #{row.first(150)}" }.join("\n")
      )
    else
      Rails.logger.info(
        "[Agent#csv_rows_output] #{url} | " +
        "No se devuelven filas (status: ok pero sin datos)"
      )
    end

    {
      url: url,
      status: "ok",
      reason: nil,
      csv_rows: final_csv_rows,
      full_code_lookups: rows_with_lookups,
      citation_validations: citation_validations,
      debug: debug,
      content_length: content_length,
      claude_response_length: claude_response.length
    }
  rescue => e
    Rails.logger.error("[Agent#extract_batch] #{url}: #{e.class}: #{e.message}")
    { url: url, status: "error", reason: "unexpected_error", csv_rows: [] }
  end

  def fetch_article_content(url)
    uri = URI(url)
    5.times do
      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = (uri.scheme == "https")
      http.read_timeout = 12
      http.open_timeout = 5

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "Mozilla/5.0 (compatible; LantiaBot/1.0)"
      req["Accept"]     = "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8"

      res = http.request(req)

      case res.code.to_i
      when 200
        charset = res.content_type&.match(/charset=([^\s;]+)/)&.captures&.first || "UTF-8"
        body    = res.body.dup.force_encoding(charset).encode("UTF-8", invalid: :replace, undef: :replace)
        return extract_text(body)
      when 301, 302, 303, 307, 308
        location = res["Location"]
        break if location.blank?
        uri = URI(location)
      else
        return nil
      end
    end
    nil
  rescue => e
    Rails.logger.warn("[Agent#fetch] #{url}: #{e.message}")
    nil
  end

  def extract_text(html)
    doc = Nokogiri::HTML(html)
    doc.css("script, style, nav, header, footer, aside, .ad, .advertisement").remove

    content_nodes = doc.css("article, [role='main'], main, .article-body, .article-content, .nota-body, .content-body, .entry-content")
    text = content_nodes.map(&:text).join("\n")

    text = doc.css("p").map(&:text).join("\n") if text.strip.length < 200
    text = doc.text                             if text.strip.length < 200

    text.gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip.presence
  end

  def call_claude_api(content, url, organizations, claude_key)
    org_catalog   = organizations.join(", ")
    user_message  = "CATÁLOGO DE ORGANIZACIONES VÁLIDAS:\n#{org_catalog}\n\nURL: #{url}\n\nTEXTO:\n#{content.first(8000)}"

    uri              = URI("https://api.anthropic.com/v1/messages")
    http             = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = true
    http.read_timeout = 60
    http.open_timeout = 10

    req = Net::HTTP::Post.new(uri)
    req["x-api-key"]         = claude_key
    req["anthropic-version"] = "2023-06-01"
    req["content-type"]      = "application/json"
    req.body = {
      model:            "claude-sonnet-4-6",
      max_tokens:       2048,
      temperature:      0.0,
      cache_control:    { type: "ephemeral" },
      system:           EXTRACTION_SYSTEM_PROMPT,
      messages:         [{ role: "user", content: user_message }]
    }.to_json

    res  = http.request(req)
    data = JSON.parse(res.body)

    # Check for API errors in response
    if data["error"]
      error_msg = "#{data['error']['type']}: #{data['error']['message']}"
      Rails.logger.error("[Agent#claude_api] #{url}: API Error: #{error_msg}")
      return { error: error_msg }
    end

    text = data.dig("content", 0, "text")
    return { error: "Empty response from Claude" } if text.blank?
    text
  rescue => e
    Rails.logger.error("[Agent#claude_api] #{url}: #{e.class}: #{e.message}")
    { error: "#{e.class}: #{e.message}" }
  end

  def lookup_full_code(municipio_name, estado_name, url = nil)
    return nil if municipio_name.blank? || estado_name.blank?

    search_log = []
    search_log << "FULL_CODE LOOKUP: municipio=#{municipio_name.inspect}, estado=#{estado_name.inspect}"

    # Step 1: Find state by name (normalizado, sin acentos)
    state = find_state(estado_name, search_log)
    if state.blank?
      Rails.logger.warn("[Agent#lookup] #{url || 'unknown'} | Estado NO encontrado: #{estado_name.inspect}")
      return { full_code: nil, method: "estado_not_found", search_log: search_log }
    end

    # Step 2: Búsqueda principal: include? (normalizado, sin acentos, case-insensitive)
    county = find_county_by_include(municipio_name, state, search_log)
    if county
      Rails.logger.info("[Agent#lookup] #{url || 'unknown'} | ✓ INCLUDE MATCH: #{municipio_name.inspect} → #{county.full_code} (#{county.name})")
      return { full_code: county.full_code, method: "include_match", search_log: search_log }
    end

    # Step 3: Fallback: Búsqueda en aliases
    county = find_county_by_alias(municipio_name, state, search_log)
    if county
      Rails.logger.info("[Agent#lookup] #{url || 'unknown'} | ✓ ALIAS MATCH: #{municipio_name.inspect} → #{county.full_code} (#{county.name})")
      return { full_code: county.full_code, method: "alias_match", search_log: search_log }
    end

    Rails.logger.warn("[Agent#lookup] #{url || 'unknown'} | ✗ NOT FOUND: #{municipio_name.inspect} en #{estado_name.inspect}")
    { full_code: nil, method: "not_found", search_log: search_log }
  rescue => e
    Rails.logger.error("[Agent#lookup_full_code] #{url || 'unknown'} | #{e.class}: #{e.message}")
    { full_code: nil, method: "error", search_log: ["Error: #{e.message}"] }
  end

  def find_state(estado_name, search_log)
    # Búsqueda con normalización (sin acentos, case-insensitive)
    normalized_query = I18n.transliterate(estado_name.downcase)
    state = State.all.find do |s|
      I18n.transliterate(s.name.downcase) == normalized_query
    end

    if state
      search_log << "✓ Estado encontrado: #{state.name}"
      return state
    end

    search_log << "✗ Estado no encontrado: #{estado_name}"
    nil
  end

  def find_county_by_include(municipio_name, state, search_log)
    search_log << "Búsqueda: #{municipio_name.inspect} contiene/contenido en #{state.name}"

    # Normalizar búsqueda (sin acentos, minúsculas)
    normalized_query = I18n.transliterate(municipio_name.downcase)

    # Buscar donde el nombre del municipio CONTIENE lo que buscamos
    county = state.counties.find do |c|
      normalized_name = I18n.transliterate(c.name.downcase)
      normalized_name.include?(normalized_query)
    end

    if county
      search_log << "  ✓ Encontrado: #{county.name} (#{county.full_code})"
    else
      search_log << "  ✗ No encontrado"
    end

    county
  end

  def find_county_by_alias(municipio_name, state, search_log)
    search_log << "Búsqueda alternativa: tabla de aliases en #{state.name}"
    state_county_ids = state.counties.pluck(:id)
    if state_county_ids.empty?
      search_log << "  ✗ No hay municipios para este estado"
      return nil
    end

    # Buscar alias con normalización
    normalized_query = I18n.transliterate(municipio_name.downcase)
    county = CountyAlias.where(county_id: state_county_ids)
                        .find { |ca| I18n.transliterate(ca.alias_name.downcase).include?(normalized_query) }
                        &.county

    if county
      search_log << "  ✓ Encontrado por alias: #{county.name} (#{county.full_code})"
    else
      search_log << "  ✗ No encontrado"
    end

    county
  end

  def criminal_organizations
    Sector.where(scian2: 98).last
          .organizations
          .where(active: true)
          .distinct
          .pluck(:name)
          .sort
  rescue => e
    Rails.logger.error("[Agent] criminal_organizations: #{e.message}")
    []
  end

  def get_organizations
    sector = Sector.where(scian2: 98).last

    if sector.nil?
      Rails.logger.warn("[Agent#get_organizations] ❌ NO HAY SECTOR con scian2=98")
      return render json: { organizations: [], error: "No sector found with scian2=98" }
    end

    all_orgs = sector.organizations.where(active: true).distinct.sort_by { |org| org.name }
    orgs_with_ids = all_orgs.map { |org| { id: org.id, name: org.name } }

    Rails.logger.info("[Agent#get_organizations] ✓ #{orgs_with_ids.count} organizaciones")
    render json: { organizations: orgs_with_ids }
  rescue => e
    Rails.logger.error("[Agent#get_organizations] ❌ #{e.class}: #{e.message}")
    render json: { organizations: [], error: e.message }
  end

  def get_states
    states = State.order(:name).map { |s| { name: s.name, code: s.code } }
    render json: { states: states }
  end

  def get_counties
    state_name = params[:state]
    state = State.find_by(name: state_name)
    counties = state ? state.counties.pluck(:name, :full_code).sort : []
    render json: { counties: counties }
  end

  def serper_api_key
    key_file = Rails.root.join("..", "..", "shared", "config", "serper_api_key").expand_path
    ENV["SERPER_API_KEY"].presence ||
      Rails.application.credentials.dig(:serper, :api_key) ||
      (File.read(key_file).strip if File.exist?(key_file))
  end

  def anthropic_api_key
    key_file = Rails.root.join("..", "..", "shared", "config", "anthropic_api_key").expand_path
    ENV["ANTHROPIC_API_KEY"].presence ||
      Rails.application.credentials.dig(:anthropic, :api_key) ||
      (File.read(key_file).strip if File.exist?(key_file))
  end

  # ── Monthly captures management ────────────────────────────────────────────
  def monthly_captures
    @year = (params[:year] || Date.today.year).to_i
    @month = (params[:month] || Date.today.month).to_i

    @monthly_export = DetentionsMonthlyExport.find_or_create_current_month

    begin
      month_start = Date.new(@year, @month, 1)
      month_end = month_start.end_of_month

      @captures = DetentionCapture
        .where(deleted_at: nil)
        .where(incident_date: month_start..month_end)
        .where(status: ['captured', 'validated', 'pending_review'])
        .order(id: :asc)

      @summary = DetentionCapture.monthly_summary(@year, @month)
    rescue => e
      Rails.logger.error("[Agent#monthly_captures] Error: #{e.class}: #{e.message}")
      @captures = []
      @summary = { total_captures: 0, validated: 0, pending_review: 0, duplicates: 0, rejected: 0 }
    end
  end

  # ── Export monthly captures as CSV ─────────────────────────────────────────
  def monthly_captures_export
    @year = (params[:year] || Date.today.year).to_i
    @month = (params[:month] || Date.today.month).to_i

    begin
      month_start = Date.new(@year, @month, 1)
      month_end = month_start.end_of_month

      @captures = DetentionCapture
        .where(deleted_at: nil)
        .where(incident_date: month_start..month_end)
        .where(status: ['captured', 'validated', 'pending_review'])
        .order(:incident_date)

      csv_content = generate_detention_csv(@captures, @year, @month)

      send_data csv_content,
                filename: "Capturas_#{@year}_#{@month.to_s.rjust(2, '0')}.csv",
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    rescue => e
      Rails.logger.error("[Agent#monthly_captures_export] Error: #{e.class}: #{e.message}")
      redirect_to agent_monthly_captures_path(year: @year, month: @month), alert: "Error al generar CSV: #{e.message}"
    end
  end

  def update_capture
    Rails.logger.info("[update_capture] ► INICIANDO - Captura ID: #{params[:id]}")
    Rails.logger.info("[update_capture] params.keys: #{params.keys.inspect}")
    Rails.logger.info("[update_capture] params[:detention_capture]: #{params[:detention_capture].inspect}")

    @capture = DetentionCapture.find(params[:id])
    Rails.logger.info("[update_capture] ✓ Captura encontrada - Organización actual: #{@capture.organization_id}")

    raw_params = capture_params.to_h
    Rails.logger.info("[update_capture] Parámetros originales (#{raw_params.count} campos): #{raw_params.keys.join(', ')}")

    params_to_update = raw_params.dup

    # Convert boolean fields from string to actual boolean
    boolean_fields = [:sedena, :semar, :gn, :sscp, :fgr, :ssp_estatal, :fge_pgj, :policia_municipal, :otro]
    boolean_fields.each do |field|
      if params_to_update[field].present?
        params_to_update[field] = params_to_update[field] == 'true'
      end
    end

    Rails.logger.info("[update_capture] Después de procesar booleanos (#{params_to_update.count} campos): #{params_to_update.keys.join(', ')}")

    # Process full_code to update estado, municipio, and full_code
    full_code = params_to_update[:full_code]
    Rails.logger.info("[update_capture] full_code: #{full_code.inspect}")

    if full_code.present?
      county = County.find_by(full_code: full_code)
      if county
        Rails.logger.info("[update_capture] ✓ County encontrado: #{county.name}")
        params_to_update[:estado] = county.state.name
        params_to_update[:municipio] = county.name
        params_to_update[:full_code] = county.full_code
      else
        # If full_code is invalid or not found, remove those fields from update
        Rails.logger.warn("[update_capture] ❌ County NO encontrado para full_code: #{full_code}")
        params_to_update.delete(:estado)
        params_to_update.delete(:municipio)
        params_to_update.delete(:full_code)
      end
    else
      # If no full_code provided, don't update estado/municipio/full_code
      Rails.logger.info("[update_capture] full_code vacío - no actualizando ubicación")
      params_to_update.delete(:estado)
      params_to_update.delete(:municipio)
      params_to_update.delete(:full_code)
    end

    Rails.logger.info("[update_capture] FINAL - Campos a actualizar (#{params_to_update.count}): #{params_to_update.keys.join(', ')}")
    Rails.logger.debug("[update_capture] Valores finales: #{params_to_update.inspect}")

    Rails.logger.info("[update_capture] ► Intentando update con:")
    Rails.logger.info("[update_capture]   - organizacion: #{params_to_update[:organizacion].inspect}")
    Rails.logger.info("[update_capture]   - organization_id: #{params_to_update[:organization_id].inspect}")

    update_result = @capture.update(params_to_update)

    Rails.logger.info("[update_capture] Update resultado: #{update_result}")
    Rails.logger.info("[update_capture] Captura después del update - org_id: #{@capture.organization_id}, organizacion: #{@capture.organizacion.inspect}")

    if update_result
      render json: { success: true, message: "Captura actualizada exitosamente" }
    else
      Rails.logger.error("[update_capture] ❌ Update falló - Errores: #{@capture.errors.full_messages.inspect}")
      render json: { success: false, errors: @capture.errors.full_messages }
    end
  end

  def delete_capture
    @capture = DetentionCapture.find(params[:id])

    if @capture.soft_delete
      render json: { success: true, message: "Captura eliminada exitosamente" }
    else
      render json: { success: false, errors: @capture.errors.full_messages }
    end
  end

  def create_hit_from_capture
    @capture = DetentionCapture.find(params[:id])
    errors = []

    Rails.logger.info("[create_hit] Iniciando creación de Hit desde DetentionCapture #{@capture.id}")
    Rails.logger.info("[create_hit] Parámetros recibidos: #{params.inspect}")
    Rails.logger.info("[create_hit] params[:hit] = #{params[:hit].inspect}")
    Rails.logger.info("[create_hit] ¿PDF presente? #{params[:hit]&.dig(:pdf).present?}")

    # Validaciones básicas
    if @capture.source_url.blank?
      errors << "URL de la noticia es requerida"
    end

    if @capture.incident_date.blank?
      errors << "Fecha del incidente es requerida"
    end

    if @capture.full_code.blank?
      errors << "Código de ubicación es requerido"
    end

    if @capture.organizacion.blank? || @capture.municipio.blank? || @capture.estado.blank?
      errors << "Información de ubicación incompleta (organización, municipio, estado)"
    end

    if errors.any?
      Rails.logger.warn("[create_hit] ❌ Validaciones fallaron: #{errors.inspect}")
      return render json: { success: false, errors: errors }
    end

    # Resolver town_id desde full_code
    full_code = @capture.full_code.to_s.strip
    town_full_code = "#{full_code}0000"
    town = Town.find_by(full_code: town_full_code)

    if town.nil?
      error_msg = "No se encontró Town para full_code=#{town_full_code}"
      Rails.logger.error("[create_hit] ❌ #{error_msg}")
      return render json: { success: false, errors: [error_msg] }
    end

    # Generar datos del Hit
    date = @capture.incident_date
    title = "#{@capture.organization&.name || @capture.organizacion} en #{@capture.municipio}, #{@capture.estado}"
    link = @capture.source_url

    # Verificar si el Hit ya existe (reutilizar)
    existing_hit = Hit.find_by(link: link)
    if existing_hit.present?
      Rails.logger.info("[create_hit] ℹ️ Hit ya existe con mismo link, reutilizando: #{existing_hit.id}")
      return render json: {
        success: true,
        message: "Hit reutilizado de captura anterior",
        hit_id: existing_hit.id,
        legacy_id: existing_hit.legacy_id,
        pdf_attached: existing_hit.pdf.attached?,
        hit_reused: true
      }
    end

    # Generar legacy_id
    require 'securerandom'
    require 'uri'
    domain = begin
      URI.parse(link).host.to_s.sub(/\Awww\./, "")
    rescue
      ""
    end

    user = current_user_safe rescue nil
    initials = if user&.respond_to?(:member) && user.member
                 [
                   user.member.firstname.to_s[0],
                   user.member.lastname1.to_s[0]
                 ].compact.join.upcase
               else
                 "XX"
               end

    date_str = date.strftime("%d%m%y")
    random_str = SecureRandom.random_bytes(2).unpack('H*')[0].upcase[0, 4]
    legacy_id = "#{domain}_#{date_str}_#{initials}_#{random_str}"

    # Crear Hit
    hit = Hit.new(
      date: date,
      title: title,
      link: link,
      town_id: town.id,
      legacy_id: legacy_id,
      user_id: user&.id
    )

    if hit.save
      # Procesar archivo PDF si existe
      if params[:hit]&.dig(:pdf).present?
        begin
          hit.pdf.attach(params[:hit][:pdf])
          Rails.logger.info("[create_hit] ✓ PDF adjunto exitosamente: #{params[:hit][:pdf].original_filename}")
        rescue => e
          Rails.logger.error("[create_hit] ⚠️ Error al adjuntar PDF: #{e.message}")
        end
      end

      Rails.logger.info("[create_hit] ✓ Hit creado exitosamente: #{hit.id} (legacy_id: #{legacy_id})")
      render json: {
        success: true,
        message: "Hit creado exitosamente",
        hit_id: hit.id,
        legacy_id: hit.legacy_id,
        pdf_attached: hit.pdf.attached?,
        hit_reused: false
      }
    else
      Rails.logger.error("[create_hit] ❌ Error al guardar Hit: #{hit.errors.full_messages.inspect}")
      render json: { success: false, errors: hit.errors.full_messages }
    end
  end

  def create_member_from_capture
    @capture = DetentionCapture.find(params[:id])
    errors = []

    timestamp = Time.current.strftime("%H:%M:%S.%L")
    Rails.logger.info("")
    Rails.logger.info("╔═══════════════════════════════════════════════════════════════╗")
    Rails.logger.info("║ [#{timestamp}] INICIO: create_member_from_capture                 ║")
    Rails.logger.info("╚═══════════════════════════════════════════════════════════════╝")
    Rails.logger.info("[create_member] DetentionCapture ID: #{@capture.id}")
    Rails.logger.info("[create_member] Nombre: #{@capture.nombre} #{@capture.apellido_paterno} #{@capture.apellido_materno}")

    # ═══ VALIDACIONES INICIALES ═══
    Rails.logger.info("[create_member] ▶ Validando datos maestros (Hit, Role, Organization)...")

    hit = Hit.find_by(id: params[:hit_id])
    if hit.nil?
      error_msg = "Hit con ID #{params[:hit_id]} no encontrado"
      Rails.logger.error("[create_member] ❌ VALIDACIÓN FALLIDA: #{error_msg}")
      return render json: { success: false, errors: [error_msg] }
    end
    Rails.logger.info("[create_member]   ✓ Hit validado: #{hit.id} (legacy_id: #{hit.legacy_id})")

    # Validar Role existe (buscar por nombre desde DetentionCapture)
    role_name = params[:role_name].to_s.strip
    if role_name.blank?
      error_msg = "Rol no especificado en la detención"
      Rails.logger.error("[create_member] ❌ VALIDACIÓN FALLIDA: #{error_msg}")
      return render json: { success: false, errors: [error_msg] }
    end

    role = Role.find_by(name: role_name)
    if role.nil?
      error_msg = "Rol '#{role_name}' no encontrado en BD"
      Rails.logger.error("[create_member] ❌ VALIDACIÓN FALLIDA: #{error_msg}")
      return render json: { success: false, errors: [error_msg] }
    end
    Rails.logger.info("[create_member]   ✓ Role validado: #{role.name} (ID: #{role.id})")

    org = Organization.find_by(id: params[:organization_id])
    if org.nil?
      error_msg = "Organización con ID #{params[:organization_id]} no encontrada"
      Rails.logger.error("[create_member] ❌ VALIDACIÓN FALLIDA: #{error_msg}")
      return render json: { success: false, errors: [error_msg] }
    end
    Rails.logger.info("[create_member]   ✓ Organization validada: #{org.name} (ID: #{org.id}, criminal_link_id: #{org.criminal_link_id})")

    # ═══ EXTRAER DATOS ═══
    Rails.logger.info("[create_member] ▶ Extrayendo datos de formulario...")
    firstname = @capture.nombre.to_s.strip
    lastname1 = @capture.apellido_paterno.to_s.strip
    lastname2 = @capture.apellido_materno.to_s.strip
    alias_raw = params[:alias_raw].to_s.strip
    gender_from_form = params[:gender].to_s.strip

    if firstname.blank? || lastname1.blank? || lastname2.blank?
      error_msg = "Nombre y apellidos son requeridos"
      Rails.logger.error("[create_member] ❌ VALIDACIÓN FALLIDA: #{error_msg}")
      return render json: { success: false, errors: [error_msg] }
    end

    Rails.logger.info("[create_member]   Firstname: #{firstname}")
    Rails.logger.info("[create_member]   Lastname1: #{lastname1}")
    Rails.logger.info("[create_member]   Lastname2: #{lastname2}")
    Rails.logger.info("[create_member]   Gender (formulario): #{gender_from_form.present? ? gender_from_form : 'VACÍO (se estimará)'}")
    Rails.logger.info("[create_member]   Alias: #{alias_raw.present? ? alias_raw : 'NINGUNO'}")

    # ═══ BÚSQUEDA DE MATCH (exacto + fuzzy + fake_identities) ═══
    Rails.logger.info("[create_member] ▶ Buscando Member existente...")
    Rails.logger.info("[create_member]   Buscando: #{firstname} #{lastname1} #{lastname2}")
    existing_member = search_member_with_fake_identities(firstname, lastname1, lastname2)
    Rails.logger.info("[create_member]   Resultado: #{existing_member.present? ? "ENCONTRADO (ID: #{existing_member.id})" : 'NO ENCONTRADO'}")

    if existing_member.present?
      Rails.logger.info("[create_member] ┌─ RAMA: MEMBER EXISTENTE (UPDATE)")
      Rails.logger.info("[create_member] │ ID: #{existing_member.id}")
      Rails.logger.info("[create_member] │ Nombre actual: #{existing_member.firstname} #{existing_member.lastname1} #{existing_member.lastname2}")
      Rails.logger.info("[create_member] │ Organization actual: #{existing_member.organization&.name} (ID: #{existing_member.organization_id})")
      Rails.logger.info("[create_member] │ Role actual: #{existing_member.role&.name} (ID: #{existing_member.role_id})")
      Rails.logger.info("[create_member] │ Criminal Link actual: #{existing_member.criminal_link&.name} (ID: #{existing_member.criminal_link_id})")

      # ═══ UPDATE MEMBER EXISTENTE ═══
      Rails.logger.info("[create_member] ├─ Preparando UPDATE...")
      update_data = { involved: true }
      Rails.logger.info("[create_member] │ ✓ involved = true")

      # Actualizar rol si el Member no tiene uno
      if existing_member.role_id.nil?
        update_data[:role_id] = role.id
        Rails.logger.info("[create_member] │ ✓ role_id será actualizado: #{role.name} (ID: #{role.id})")
      else
        Rails.logger.info("[create_member] │ ℹ️ role_id NO se cambia (ya tiene uno)")
      end

      # Calcular criminal_role según involved=true
      new_criminal_role = compute_criminal_role(true, role.name)
      update_data[:criminal_role] = new_criminal_role
      Rails.logger.info("[create_member] │ ✓ criminal_role calculado: #{new_criminal_role}")

      # Criminal Link: Si Member existente tiene org NO-criminal → asignar como criminal_link
      if existing_member.organization_id.present? && existing_member.criminal_link_id.blank?
        existing_org = Organization.find_by(id: existing_member.organization_id)
        if existing_org&.criminal_link_id.blank?
          update_data[:criminal_link_id] = org.id
          Rails.logger.info("[create_member] │ ✓ criminal_link_id asignado desde formulario: #{org.name} (ID: #{org.id})")
        else
          Rails.logger.info("[create_member] │ ℹ️ criminal_link_id NO se cambia (org existente ya tiene uno)")
        end
      else
        Rails.logger.info("[create_member] │ ℹ️ criminal_link_id NO se cambia (ya existe o no aplica)")
      end

      existing_member.update(update_data)
      Rails.logger.info("[create_member] │ ✓ Member actualizado")

      # Merge alias
      if alias_raw.present?
        alias_array = alias_raw.split(';').map(&:strip).reject(&:empty?)
        current_aliases = Array(existing_member.alias).map(&:to_s)
        merged_aliases = (current_aliases + alias_array).map(&:strip).reject(&:blank?).uniq
        existing_member.update(alias: merged_aliases)
        Rails.logger.info("[create_member] │ ✓ Alias mergeados: #{merged_aliases.join(', ')}")
      else
        Rails.logger.info("[create_member] │ ℹ️ Sin alias nuevos para mergear")
      end

      # Agregar Hit si no está ya asociado
      if existing_member.hits.exists?(hit.id)
        Rails.logger.info("[create_member] │ ℹ️ Hit #{hit.id} ya estaba asociado")
      else
        existing_member.hits << hit
        Rails.logger.info("[create_member] │ ✓ Hit #{hit.id} asociado al Member")
      end

      Rails.logger.info("[create_member] └─ ✅ ÉXITO: Member existente actualizado")
      Rails.logger.info("")

      # Marcar DetentionCapture como member_added
      @capture.update(member_added: true)
      Rails.logger.info("[create_member] ✓ DetentionCapture ID #{@capture.id} marcada como member_added = true")

      render json: {
        success: true,
        message: "Member existente actualizado",
        member_id: existing_member.id,
        member_existed: true
      }
    else
      # ═══ CREAR NUEVO MEMBER ═══
      Rails.logger.info("[create_member] ┌─ RAMA: CREAR NUEVO MEMBER")

      # Género: usar del formulario, si está vacío usar estimado
      Rails.logger.info("[create_member] ├─ Determinando GENDER...")
      gender_value = if gender_from_form.present? && ["MASCULINO", "FEMENINO"].include?(gender_from_form)
                       Rails.logger.info("[create_member] │ ✓ Gender desde formulario: #{gender_from_form}")
                       gender_from_form
                     else
                       estimated = estimate_gender(firstname)
                       Rails.logger.info("[create_member] │ ✓ Gender estimado desde CSV: #{estimated || 'FALLIDO - usando MASCULINO como fallback'}")
                       estimated || "MASCULINO"
                     end

      # Para detenciones, involved es siempre true
      involved_value = true
      Rails.logger.info("[create_member] │ ✓ involved = true (son detenidos)")

      # Calcular criminal_role
      criminal_role_value = compute_criminal_role(involved_value, role.name)
      Rails.logger.info("[create_member] │ ✓ criminal_role calculado: #{criminal_role_value} (según role: #{role.name})")

      # criminal_link_id: hereda de organización
      criminal_link_id_value = org&.criminal_link_id
      Rails.logger.info("[create_member] │ ✓ criminal_link_id heredado de org: #{criminal_link_id_value || 'NINGUNO'}")

      # Procesar alias (guardar como Array en campo alias del Member)
      alias_array = if alias_raw.present?
                      alias_raw.split(';').map(&:strip).reject(&:empty?)
                    else
                      []
                    end
      Rails.logger.info("[create_member] │ ✓ Alias procesados: #{alias_array.present? ? alias_array.join(', ') : 'ninguno'}")

      # Crear Member
      Rails.logger.info("[create_member] ├─ Creando record de Member en BD...")
      new_member = Member.new(
        firstname: firstname,
        lastname1: lastname1,
        lastname2: lastname2,
        organization_id: org.id,
        role_id: role.id,
        gender: gender_value,
        involved: involved_value,
        criminal_role: criminal_role_value,
        criminal_link_id: criminal_link_id_value,
        alias: alias_array
      )

      if new_member.save
        Rails.logger.info("[create_member] │ ✓ Member guardado en BD (ID: #{new_member.id})")

        # Asociar Hit
        new_member.hits << hit
        Rails.logger.info("[create_member] │ ✓ Hit #{hit.id} asociado")

        # Aplicar rol en femenino si corresponde
        apply_feminine_role_if_needed(new_member)

        Rails.logger.info("[create_member] ├─ RESUMEN DE CREACIÓN:")
        Rails.logger.info("[create_member] │ ID: #{new_member.id}")
        Rails.logger.info("[create_member] │ Nombre: #{new_member.firstname} #{new_member.lastname1} #{new_member.lastname2}")
        Rails.logger.info("[create_member] │ Organization: #{new_member.organization&.name}")
        Rails.logger.info("[create_member] │ Role: #{new_member.role&.name}")
        Rails.logger.info("[create_member] │ Gender: #{new_member.gender}")
        Rails.logger.info("[create_member] │ Involved: #{new_member.involved}")
        Rails.logger.info("[create_member] │ Criminal Role: #{new_member.criminal_role}")
        Rails.logger.info("[create_member] │ Criminal Link: #{new_member.criminal_link&.name}")
        Rails.logger.info("[create_member] └─ ✅ ÉXITO: Member creado exitosamente")
        Rails.logger.info("")

        # Marcar DetentionCapture como member_added
        @capture.update(member_added: true)
        Rails.logger.info("[create_member] ✓ DetentionCapture ID #{@capture.id} marcada como member_added = true")

        render json: {
          success: true,
          message: "Member creado exitosamente",
          member_id: new_member.id,
          member_existed: false
        }
      else
        Rails.logger.error("[create_member] ├─ ❌ ERROR al guardar Member")
        Rails.logger.error("[create_member] │ Errores: #{new_member.errors.full_messages.inspect}")
        Rails.logger.error("[create_member] └─ FALLÓ: create_member_from_capture")
        Rails.logger.error("")
        render json: { success: false, errors: new_member.errors.full_messages }
      end
    end
  end

  def apply_feminine_role_if_needed(member)
    Rails.logger.info("[feminine_role] ▶ Verificando si se debe aplicar rol femenino...")
    Rails.logger.info("[feminine_role] │ Gender: #{member.gender}")
    Rails.logger.info("[feminine_role] │ Role ID: #{member.role_id}")

    return Rails.logger.info("[feminine_role] ✗ No aplica (gender no es FEMENINO)") if member.gender != "FEMENINO"
    return Rails.logger.info("[feminine_role] ✗ No aplica (sin role_id)") if member.role_id.blank?

    role = member.role
    return Rails.logger.info("[feminine_role] ✗ No aplica (role no encontrado)") if role.nil?

    Rails.logger.info("[feminine_role] │ Role actual: #{role.name}")

    feminine_map = get_feminine_role_map
    feminine_role_name = feminine_map[role.name]

    if feminine_role_name.nil?
      Rails.logger.info("[feminine_role] ℹ️ No hay mapeo femenino para: #{role.name}")
      return
    end

    Rails.logger.info("[feminine_role] │ Buscando rol femenino: #{feminine_role_name}")

    # Buscar si existe rol femenino, si no, dejar el original
    feminine_role = Role.find_by(name: feminine_role_name)
    if feminine_role.present?
      member.update(role_id: feminine_role.id)
      Rails.logger.info("[feminine_role] ✓ Rol ajustado a femenino: #{feminine_role_name} (ID: #{feminine_role.id})")
    else
      Rails.logger.warn("[feminine_role] ⚠️ Rol femenino '#{feminine_role_name}' no existe en BD")
    end
  rescue => e
    Rails.logger.error("[feminine_role] ❌ Error al aplicar rol femenino: #{e.message}")
  end

  private

  def estimate_gender(firstname)
    return nil if firstname.blank?

    gender_file = if Rails.env.production?
                    "/var/www/lantiamaster/shared/names_by_gender.csv"
                  else
                    Rails.root.join("scripts", "names_by_gender.csv").to_s
                  end

    unless File.exist?(gender_file)
      Rails.logger.warn("[estimate_gender] ⚠️ CSV no encontrado: #{gender_file}")
      return nil
    end

    row = CSV.read(gender_file, headers: true).find do |r|
      r["firstname"].to_s.strip.downcase == firstname.to_s.strip.downcase
    end

    if row.nil?
      Rails.logger.info("[estimate_gender] ℹ️ '#{firstname}' no encontrado en CSV")
      return nil
    end

    estimated = row&.[]("genero_estimado").to_s.strip.downcase
    result = case estimated
             when "masculino" then "MASCULINO"
             when "femenino"  then "FEMENINO"
             else nil
             end

    Rails.logger.info("[estimate_gender] ✓ '#{firstname}' estimado como: #{result || 'DESCONOCIDO'}")
    result
  rescue => e
    Rails.logger.error("[estimate_gender] ❌ Error al estimar gender: #{e.message}")
    nil
  end

  def get_feminine_role_map
    {
      "Padre" => "Madre",
      "Hijo" => "Hija",
      "Abuelo" => "Abuela",
      "Nieto" => "Nieta",
      "Tio" => "Tia",
      "Sobrino" => "Sobrina",
      "Padrino" => "Madrina",
      "Ahijado" => "Ahijada",
      "Abogado" => "Abogada",
      "Defendido" => "Defendida",
      "Jefe" => "Jefa",
      "Colaborador" => "Colaboradora",
      "Hermano" => "Hermana",
      "Compañero" => "Compañera",
      "Amigo" => "Amiga",
      "Primo" => "Prima",
      "Conyuge" => "Conyuge",
      "Pareja" => "Pareja",
      "Esposo" => "Esposa",
      "Socio" => "Socia",
      "Allegado" => "Allegada",
      "Compadre" => "Comadre",
      "Cuñado" => "Cuñada",
      "Suegro" => "Suegra",
      "Yerno" => "Nuera"
    }
  end

  def members_similar?(member1, member2)
    fn1 = I18n.transliterate(member1.firstname.to_s.downcase)
    ln1a = I18n.transliterate(member1.lastname1.to_s.downcase)
    ln1b = I18n.transliterate(member1.lastname2.to_s.downcase)

    fn2 = I18n.transliterate(member2.firstname.to_s.downcase)
    ln2a = I18n.transliterate(member2.lastname1.to_s.downcase)
    ln2b = I18n.transliterate(member2.lastname2.to_s.downcase)

    firstname_match = fn1.include?(fn2) || fn2.include?(fn1)
    lastname1_match = ln1a.include?(ln2a) || ln2a.include?(ln1a)
    lastname2_match = ln1b.include?(ln2b) || ln2b.include?(ln1b)

    firstname_match && lastname1_match && lastname2_match
  end

  def search_member_with_fake_identities(firstname, lastname1, lastname2)
    candidate = OpenStruct.new(firstname: firstname, lastname1: lastname1, lastname2: lastname2)

    # Búsqueda EXACTA: nombre principal exacto
    Rails.logger.info("[search] ▶ Búsqueda EXACTA: #{firstname} #{lastname1} #{lastname2}")
    exact_match = Member.find_by(firstname: firstname, lastname1: lastname1, lastname2: lastname2)
    if exact_match.present?
      Rails.logger.info("[search] ✓ EXACTO encontrado: #{exact_match.id}")
      return exact_match
    end
    Rails.logger.info("[search] ✗ Exacto no encontrado")

    # Búsqueda FUZZY: en nombres principales (con filtro de nombres completos)
    Rails.logger.info("[search] ▶ Búsqueda FUZZY en Members con nombres completos...")
    fuzzy_match = Member.where.not(firstname: [nil, ''])
                        .where.not(lastname1: [nil, ''])
                        .where.not(lastname2: [nil, ''])
                        .find do |m|
                          members_similar?(m, candidate)
                        end
    if fuzzy_match.present?
      Rails.logger.info("[search] ✓ FUZZY encontrado: #{fuzzy_match.id}")
      return fuzzy_match
    end
    Rails.logger.info("[search] ✗ Fuzzy no encontrado")

    # Búsqueda en FAKE IDENTITIES: valida contra identidades falsas existentes
    Rails.logger.info("[search] ▶ Búsqueda en FAKE IDENTITIES con nombres completos...")
    fake_match = nil
    fake_search_count = 0

    FakeIdentity.where.not(firstname: [nil, ''])
                .where.not(lastname1: [nil, ''])
                .where.not(lastname2: [nil, ''])
                .each do |fake_id|
      fake_search_count += 1
      fake_candidate = OpenStruct.new(
        firstname: fake_id.firstname,
        lastname1: fake_id.lastname1,
        lastname2: fake_id.lastname2
      )
      if members_similar?(fake_candidate, candidate)
        Rails.logger.info("[search] ✓ FAKE IDENTITY encontrada: #{fake_id.firstname} #{fake_id.lastname1} #{fake_id.lastname2} → Member #{fake_id.member_id}")
        fake_match = fake_id.member
        break
      end
    end

    if fake_match.nil?
      Rails.logger.info("[search] ✗ Fake identities no encontradas (#{fake_search_count} revisadas)")
    end

    fake_match
  end

  def compute_criminal_role(involved_value, role_name)
    return nil if role_name.blank?

    Rails.logger.info("[compute_criminal] ▶ Calculando criminal_role")
    Rails.logger.info("[compute_criminal] │ involved: #{involved_value}")
    Rails.logger.info("[compute_criminal] │ role_name: #{role_name}")

    lookup_true = {
      "Líder" => "Líder",
      "Extorsionador" => "Miembro",
      "Jefe operativo" => "Miembro",
      "Sicario" => "Miembro",
      "Jefe de plaza" => "Miembro",
      "Operador" => "Miembro",
      "Jefe de célula" => "Miembro",
      "Traficante o distribuidor" => "Miembro",
      "Narcomenudista" => "Miembro",
      "Jefe de sicarios" => "Miembro",
      "Jefe regional" => "Miembro",
      "Abogado" => "Socio",
      "Manager" => "Socio",
      "Socio" => "Socio",
      "Artista" => "Socio",
      "Dirigente sindical" => "Socio",
      "Músico" => "Socio",
      "Alcalde" => "Autoridad vinculada",
      "Militar" => "Autoridad vinculada",
      "Coordinador estatal" => "Autoridad vinculada",
      "Regidor" => "Autoridad vinculada",
      "Policía" => "Autoridad vinculada",
      "Delegado estatal" => "Autoridad vinculada",
      "Gobernador" => "Autoridad vinculada",
      "Autoridad cooptada" => "Autoridad vinculada",
      "Secretario de Seguridad" => "Autoridad vinculada",
      "Sin definir" => nil
    }

    lookup_false = {
      "Regidor" => "Autoridad expuesta",
      "Policía" => "Autoridad expuesta",
      "Delegado estatal" => "Autoridad expuesta",
      "Autoridad expuesta" => "Autoridad expuesta",
      "Gobernador" => "Autoridad expuesta",
      "Alcalde" => "Autoridad expuesta",
      "Secretario de Seguridad" => "Autoridad expuesta",
      "Servicios lícitos" => "Servicios lícitos",
      "Abogado" => "Servicios lícitos",
      "Manager" => "Servicios lícitos",
      "Artista" => "Servicios lícitos",
      "Dirigente sindical" => "Servicios lícitos",
      "Músico" => "Servicios lícitos",
      "Familiar" => "Familiar/allegado",
      "Sin definir" => nil
    }

    result = involved_value ? lookup_true[role_name] : lookup_false[role_name]
    Rails.logger.info("[compute_criminal] ✓ Resultado: #{result || 'nil (Sin definir)'}")
    result
  end

  def get_roles
    roles = Role.all.map { |r| { id: r.id, name: r.name } }
    render json: { success: true, roles: roles }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # MEDIA MONITORING - NEW METHODS
  # ═══════════════════════════════════════════════════════════════════════════

  def media_monitoring
    @page_title = "Agente de captura — Monitoreo de medios"
  end

  def search_media
    api_key = serper_api_key
    return render json: { error: "SERPER_API_KEY no configurada." }, status: :service_unavailable if api_key.blank?

    results = []
    mutex = Mutex.new

    media_queries = [
      %("cartel" "captura" OR "detenido" OR "operativo"),
      %("CJNG" "operativo"),
      %("Cártel de Sinaloa" "captura"),
      %("Cárteles Unidos" "detenidos"),
      %("Familia Michoacana" "operativo"),
      %(cartel Mexico "2026")
    ]

    threads = media_queries.map do |query|
      Thread.new do
        begin
          uri = URI("https://google.serper.dev/news")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.read_timeout = 10
          http.open_timeout = 5

          req = Net::HTTP::Post.new(uri)
          req["X-API-KEY"] = api_key
          req["Content-Type"] = "application/json"
          req.body = { q: query, tbs: "qdr:d", gl: "mx", hl: "es", num: 10 }.to_json

          res = http.request(req)
          data = JSON.parse(res.body)
          mutex.synchronize { results.concat(data["news"] || []) } if data["news"].is_a?(Array)
        rescue => e
          Rails.logger.error("[Agent#search_media] #{query.inspect} #{e.class}: #{e.message}")
        end
      end
    end

    threads.each(&:join)

    seen = {}
    unique = results.select { |a| a["link"] && seen[a["link"]] ? false : (seen[a["link"]] = true) }

    formatted_results = unique.map do |article|
      {
        title: article["title"] || "(Sin título)",
        link: article["link"] || "",
        source_domain: URI.parse(article["link"] || "").host || "unknown",
        published_date: article["date"] || Time.now.strftime("%d/%m/%Y"),
        snippet: article["snippet"] || ""
      }
    end

    render json: { results: formatted_results }
  end

  def extract_media_batch
    body = JSON.parse(request.raw_post)
    urls = (body["urls"] || []).map(&:to_s).compact.select { |u| u.present? }

    return render json: { error: "No URLs provided" }, status: :bad_request if urls.blank?

    claude_key = anthropic_api_key
    return render json: { error: "ANTHROPIC_API_KEY no configurada." }, status: :service_unavailable if claude_key.blank?

    log = []
    extracted_count = 0
    error_count = 0

    urls.each do |url|
      begin
        result = extract_hit_from_url(url, claude_key)

        if result[:success]
          extracted_count += 1
          log << { url: url, status: "extracted", message: "Hit creado exitosamente" }
        else
          error_count += 1
          log << { url: url, status: "error", message: result[:error] || "Error desconocido" }
        end
      rescue => e
        error_count += 1
        log << { url: url, status: "error", message: e.message }
        Rails.logger.error("[Agent#extract_media_batch] #{url} | #{e.class}: #{e.message}")
      end
    end

    render json: {
      log: log,
      summary: {
        total: urls.length,
        extracted: extracted_count,
        errors: error_count
      }
    }
  end

  def extract_media_url
    body = JSON.parse(request.raw_post)
    url = body["url"].to_s.strip

    return render json: { error: "URL vacía" }, status: :bad_request if url.blank?

    claude_key = anthropic_api_key
    return render json: { error: "ANTHROPIC_API_KEY no configurada." }, status: :service_unavailable if claude_key.blank?

    result = extract_hit_from_url(url, claude_key)
    render json: { success: result[:success], error: result[:error], hit_id: result[:hit_id] }
  end

  def media_hits
    @hits = Hit.all.order(created_at: :desc).limit(100)
  end

  def update_media_hit
    @hit = Hit.find(params[:id])
    hit_params_safe = params.require(:hit).permit(:title, :date, :link)

    if @hit.update(hit_params_safe)
      render json: { success: true, message: "Hit actualizado exitosamente" }
    else
      render json: { success: false, error: @hit.errors.full_messages.join(", ") }
    end
  end

  def delete_media_hit
    @hit = Hit.find(params[:id])

    if @hit.destroy
      render json: { success: true, message: "Hit eliminado exitosamente" }
    else
      render json: { success: false, error: @hit.errors.full_messages.join(", ") }
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE
  # ═══════════════════════════════════════════════════════════════════════════
  private

  def save_csv_row_to_db(csv_row, url, estado, municipio, full_code)
    return nil if csv_row.blank?

    fields = CSV.parse_line(csv_row, col_sep: ",")

    # LOGUEAR INTENTO
    pessoa_info = "#{fields[10] || '?'} #{fields[11] || '?'}" rescue "?"
    Rails.logger.info(
      "[Agent#save_csv] #{url} | Intento guardar: " +
      "#{pessoa_info} | " +
      "Estado: #{estado} | Municipio: #{municipio} | " +
      "Campos: #{fields.length}"
    )

    # VALIDACIÓN 1: Campos suficientes
    if fields.blank? || fields.length < 28
      Rails.logger.warn(
        "[Agent#save_csv] #{url} | ❌ RECHAZADO | " +
        "Razón: campos_insuficientes (#{fields.length} vs 28) | " +
        "Persona: #{pessoa_info}"
      )
      return nil
    end

    detenidos_value = fields[7].to_i

    # VALIDACIÓN 2: Detenidos > 0
    if detenidos_value == 0
      Rails.logger.warn(
        "[Agent#save_csv] #{url} | ❌ RECHAZADO | " +
        "Razón: detenidos_is_zero | " +
        "Persona: #{pessoa_info} | " +
        "Detenidos: #{detenidos_value}"
      )
      return { status: 'rejected', reason: 'detenidos_is_zero', message: 'Registro rechazado: número de detenidos no puede ser 0' }
    end

    # VALIDACIÓN 3: Estado identificado
    if estado.blank?
      Rails.logger.warn(
        "[Agent#save_csv] #{url} | ❌ RECHAZADO | " +
        "Razón: estado_not_found | " +
        "Persona: #{pessoa_info} | " +
        "Municipio: #{municipio}"
      )
      return { status: 'rejected', reason: 'estado_not_found', message: 'Registro rechazado: Estado no identificado' }
    end

    begin
      capture_date = Date.today
      incident_date = Date.new(
        2000 + fields[2].to_i,
        fields[1].to_i,
        fields[0].to_i
      ) rescue capture_date

      capture_hash = DetentionCapture.generate_hash(
        estado: fields[3],
        municipio: fields[5],
        incident_date: incident_date,
        detenidos: detenidos_value,
        organizacion: fields[8],
        nombres: [fields[10], fields[11], fields[12]].compact
      )

      # Create temporary record to check for duplicates using smart matching
      temp_capture = DetentionCapture.new(
        nombre: fields[10],
        apellido_paterno: fields[11],
        apellido_materno: fields[12],
        alias: fields[13],
        genero: fields[14],
        edad: fields[15].present? ? fields[15].to_i : nil,
        posicion_liderazgo: fields[16],
        rol: fields[17],
        sedena: fields[18] == '1',
        semar: fields[19] == '1',
        gn: fields[20] == '1',
        sscp: fields[21] == '1',
        fgr: fields[22] == '1',
        ssp_estatal: fields[23] == '1',
        fge_pgj: fields[24] == '1',
        policia_municipal: fields[25] == '1',
        otro: fields[26] == '1',
        estado: fields[3],
        organizacion: fields[8],
        grupo_afiliado: fields[9],
        incident_date: incident_date,
        validation_notes: "Merged from #{url}"
      )

      # Check for smart duplicates (nombre + apellido + estado + semana OR alias)
      duplicates = DetentionCapture.find_duplicates(temp_capture)
      if duplicates.any?
        duplicate_record = duplicates.first

        # Determinar cuál criterio se aplicó
        match_criteria = detect_match_criteria(temp_capture, duplicate_record)

        # Enriquecer el registro existente con información más completa
        merge_result = duplicate_record.merge_with_duplicate(temp_capture)

        Rails.logger.info(
          "[Agent#save_csv] #{url} | ✓ DUPLICADO DETECTADO Y ACTUALIZADO | " +
          "Persona: #{fields[10]} #{fields[11]} | " +
          "Estado: #{fields[3]} | Municipio: #{fields[5]} | " +
          "Criterio: #{match_criteria} | " +
          "ID duplicado: #{duplicate_record.id} | " +
          "Campos actualizados: #{merge_result[:fields_updated_count]} | " +
          "Razones: #{merge_result[:update_reasons].join(' | ')}"
        )

        return { status: 'duplicate_merged', id: duplicate_record.id, reason: 'smart_match', criteria: match_criteria, merge_result: merge_result }
      end

      # Also check for exact hash duplicates (fallback)
      existing = DetentionCapture.where(capture_hash: capture_hash).first
      return { status: 'duplicate', id: existing.id, hash: capture_hash } if existing

      # Buscar organization_id: prioridad a grupo_afiliado, sino organizacion
      organization_id = nil
      org_source = nil
      org_name = nil

      if fields[9].present?
        org_name = fields[9].strip
        org_source = "grupo_afiliado"
      elsif fields[8].present?
        org_name = fields[8].strip
        org_source = "organizacion"
      end

      if org_name.present? && org_source.present?
        org = Organization.where("name ILIKE ?", org_name).first

        if org
          organization_id = org.id
          Rails.logger.info(
            "[Agent#save_csv] #{url} | ORGANIZATION FOUND | " +
            "Source: #{org_source} | " +
            "Value searched: '#{org_name}' | " +
            "Organization ID: #{organization_id} | " +
            "Organization name: '#{org.name}'"
          )
        else
          Rails.logger.warn(
            "[Agent#save_csv] #{url} | ORGANIZATION NOT FOUND | " +
            "Source: #{org_source} | " +
            "Value searched: '#{org_name}'"
          )
        end
      else
        Rails.logger.warn(
          "[Agent#save_csv] #{url} | NO ORGANIZATION DATA | " +
          "grupo_afiliado: '#{fields[9]}' | " +
          "organizacion: '#{fields[8]}'"
        )
      end

      capture = DetentionCapture.create!(
        source_url: url,
        capture_date: capture_date,
        incident_date: incident_date,
        estado: fields[3],
        municipio: fields[5],
        full_code: fields[4],
        detenidos: detenidos_value,
        organizacion: fields[8],
        grupo_afiliado: fields[9],
        organization_id: organization_id,
        nombre: fields[10],
        apellido_paterno: fields[11],
        apellido_materno: fields[12],
        alias: fields[13],
        genero: fields[14],
        edad: fields[15].present? ? fields[15].to_i : nil,
        posicion_liderazgo: fields[16],
        rol: fields[17],
        sedena: fields[18] == '1',
        semar: fields[19] == '1',
        gn: fields[20] == '1',
        sscp: fields[21] == '1',
        fgr: fields[22] == '1',
        ssp_estatal: fields[23] == '1',
        fge_pgj: fields[24] == '1',
        policia_municipal: fields[25] == '1',
        otro: fields[26] == '1',
        capture_hash: capture_hash,
        status: 'captured'
      )

      Rails.logger.info(
        "[Agent#save_csv] #{url} | ✅ GUARDADO EXITOSO | " +
        "ID: #{capture.id} | " +
        "Persona: #{pessoa_info} | " +
        "Estado: #{fields[3]} | Municipio: #{fields[5]} | " +
        "Detenidos: #{detenidos_value}"
      )

      { status: 'saved', id: capture.id, hash: capture_hash }
    rescue StandardError => e
      Rails.logger.error(
        "[Agent#save_csv] #{url} | ❌ ERROR AL GUARDAR | " +
        "Persona: #{pessoa_info} | " +
        "Error: #{e.class}: #{e.message}"
      )
      { status: 'error', error: e.message }
    end
  end

  # ── Logging endpoint para validaciones del cliente ────────────────────────
  def log_client_validation
    body = JSON.parse(request.raw_post)
    url = body["url"]
    csv_rows_received = body["csv_rows_received"]
    csv_rows_accepted = body["csv_rows_accepted"]
    csv_rows_rejected = body["csv_rows_rejected"]
    rejections = body["rejections"] || []

    Rails.logger.info(
      "[Agent#client_validation] #{url} | " +
      "Recibidas: #{csv_rows_received} | Aceptadas: #{csv_rows_accepted} | Rechazadas: #{csv_rows_rejected}"
    )

    if rejections.any?
      Rails.logger.warn(
        "[Agent#client_validation] #{url} | Filas rechazadas por cliente:"
      )
      rejections.each_with_index do |rejection, idx|
        Rails.logger.warn(
          "[Agent#client_validation] #{url} | [#{idx + 1}] Razón: #{rejection['reason']} | " +
          "Preview: #{rejection['row_preview']&.first(100)}"
        )
      end
    end

    render json: { status: "logged" }
  rescue => e
    Rails.logger.error(
      "[Agent#client_validation] Error al procesar log del cliente: #{e.class}: #{e.message}"
    )
    render json: { error: e.message }, status: :bad_request
  end

  # ── Validación y corrección de filas CSV ────────────────────────────────────
  def validate_csv_row_format(row)
    fields = row.split(",")

    case
    when fields.length < 28
      { valid: false, error_type: "campos_insuficientes",
        details: "Tiene #{fields.length} campos, requiere 28" }
    when !row.match?(/\A\d{1,2},\d/)
      { valid: false, error_type: "formato_fecha_invalido",
        details: "Debe comenzar con DD,MM (ej: 25,06,26)" }
    when fields[27].blank? || !fields[27].start_with?('http')
      { valid: false, error_type: "url_invalida",
        details: "Campo 28 (Fuente) debe ser URL válida" }
    else
      { valid: true, error_type: nil, details: nil }
    end
  end

  def generate_correction_prompt(error_type, error_details)
    case error_type
    when "campos_insuficientes"
      "Tu respuesta anterior tiene #{error_details}. " +
      "Debes regenerar la fila CSV con EXACTAMENTE 28 campos separados por comas. " +
      "Mantén las líneas ###CITA exactamente iguales, solo corrige la fila CSV. " +
      "Formato: DD,MM,26,Estado,full_code,Municipio,Abatido,Detenidos,... hasta campo 28 que debe ser la URL."

    when "formato_fecha_invalido"
      "La fecha en tu CSV anterior no es válida. La fila debe comenzar con " +
      "DD,MM,26 (ejemplo: 25,06,26 para 25 de junio de 2026). " +
      "Regenera la respuesta con el formato de fecha correcto al principio de la fila CSV. " +
      "Mantén las líneas ###CITA iguales."

    when "url_invalida"
      "El campo Fuente (posición 28) debe ser una URL válida que comience con 'http'. " +
      "Regenera la fila CSV asegurándote de que el último campo es la URL completa de la nota."

    else
      "Hubo un problema con tu respuesta anterior. " +
      "Por favor regenera la fila CSV asegurándote de que: " +
      "1) Tiene exactamente 28 campos separados por comas, " +
      "2) Comienza con DD,MM,26 (formato de fecha), " +
      "3) El campo 28 es una URL válida. " +
      "Mantén las líneas ###CITA exactamente iguales."
    end
  end

  def retry_claude_with_correction(content, url, correction_message, organizations, claude_key)
    org_catalog = organizations.join(", ")
    user_message = "CATÁLOGO DE ORGANIZACIONES VÁLIDAS:\n#{org_catalog}\n\n" +
                   "URL: #{url}\n\n" +
                   "INSTRUCCIÓN DE CORRECCIÓN:\n#{correction_message}\n\n" +
                   "TEXTO:\n#{content.first(8000)}"

    uri = URI("https://api.anthropic.com/v1/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60
    http.open_timeout = 10

    req = Net::HTTP::Post.new(uri)
    req["x-api-key"] = claude_key
    req["anthropic-version"] = "2023-06-01"
    req["content-type"] = "application/json"
    req.body = {
      model: "claude-sonnet-4-6",
      max_tokens: 2048,
      temperature: 0.0,
      cache_control: { type: "ephemeral" },
      system: EXTRACTION_SYSTEM_PROMPT,
      messages: [{ role: "user", content: user_message }]
    }.to_json

    res = http.request(req)
    data = JSON.parse(res.body)

    if data["error"]
      error_msg = "#{data['error']['type']}: #{data['error']['message']}"
      Rails.logger.error("[Agent#retry_claude] #{url} | API Error: #{error_msg}")
      { error: error_msg }
    else
      text = data.dig("content", 0, "text")
      return { error: "Empty response from Claude" } if text.blank?
      text
    end
  rescue => e
    Rails.logger.error("[Agent#retry_claude] #{url} | #{e.class}: #{e.message}")
    { error: "#{e.class}: #{e.message}" }
  end

  private

  def detect_match_criteria(new_capture, existing_record)
    norm_nombre = DetentionCapture.normalize_name(new_capture.nombre)
    norm_apellido = DetentionCapture.normalize_name(new_capture.apellido_paterno)
    norm_alias = DetentionCapture.normalize_name(new_capture.alias)

    dup_norm_nombre = DetentionCapture.normalize_name(existing_record.nombre)
    dup_norm_apellido = DetentionCapture.normalize_name(existing_record.apellido_paterno)
    dup_norm_alias = DetentionCapture.normalize_name(existing_record.alias)

    # Criterio 1: Nombre + Apellido Paterno exactos
    if norm_nombre.present? && dup_norm_nombre == norm_nombre &&
       norm_apellido.present? && dup_norm_apellido == norm_apellido
      return "Criterio 1: Nombre + Apellido Paterno exactos"
    end

    # Criterio 2: Solo nombre (ambos sin apellido paterno)
    if norm_nombre.present? && dup_norm_nombre == norm_nombre &&
       norm_apellido.blank? && dup_norm_apellido.blank?
      return "Criterio 2: Solo nombre (ambos sin apellido paterno)"
    end

    # Criterio 3: Alias exacto
    if norm_alias.present? && dup_norm_alias == norm_alias
      return "Criterio 3: Alias exacto"
    end

    # Criterio 4: Nombres/apellidos parciales
    if DetentionCapture.names_are_partial_match(
      new_capture.nombre, new_capture.apellido_paterno, new_capture.apellido_materno,
      existing_record.nombre, existing_record.apellido_paterno, existing_record.apellido_materno
    )
      new_tokens = [new_capture.nombre, new_capture.apellido_paterno, new_capture.apellido_materno]
                     .compact.flat_map { |n| n.split(/\s+/) }.map { |t| DetentionCapture.normalize_name(t) }.uniq
      existing_tokens = [existing_record.nombre, existing_record.apellido_paterno, existing_record.apellido_materno]
                          .compact.flat_map { |n| n.split(/\s+/) }.map { |t| DetentionCapture.normalize_name(t) }.uniq

      return "Criterio 4: Nombres parciales (tokens: #{new_tokens.sort.join(',')} vs #{existing_tokens.sort.join(',')})"
    end

    "Criterio desconocido"
  end

  def capture_params
    params.require(:detention_capture).permit(
      :incident_date, :estado, :municipio, :full_code, :organizacion, :organization_id, :grupo_afiliado,
      :detenidos, :nombre, :apellido_paterno, :apellido_materno, :alias,
      :genero, :edad, :posicion_liderazgo, :rol, :validation_notes,
      :sedena, :semar, :gn, :sscp, :fgr, :ssp_estatal, :fge_pgj,
      :policia_municipal, :otro
    )
  end

  def generate_detention_csv(captures, year, month)
    CSV.generate(encoding: 'UTF-8', col_sep: ',') do |csv|
      # ENCABEZADOS (32 columnas - formato Base Rogelio)
      csv << [
        'Intervención',
        'Día',
        'Mes',
        'Año',
        'Estado',
        'INEGI',
        'Municipio',
        'Detenidos',
        'Organización',
        'Grupo afiliado',
        'Nombre',
        'Apellido Paterno',
        'Apellido Materno',
        'Alias',
        'Género',
        'Edad',
        'Posición de liderazgo',
        'Jefe regional',
        'SEDENA',
        'SEMAR',
        'GN',
        'SSCP',
        'FGR',
        'SSP-Estatal',
        'FGE/PGJ',
        'Policía municipal',
        'Otro',
        'Resumen',
        'Fuente',
        'Título nota',
        'Consultor',
        'Status'
      ]

      # DATOS (una fila por captura)
      captures.each_with_index do |capture, index|
        # Generar ID de Intervención en formato YYMMDDNN
        intervention_id = "#{capture.incident_date.strftime('%y%m%d')}#{(index + 1).to_s.rjust(2, '0')}"

        csv << [
          intervention_id,                                    # Intervención
          capture.incident_date.day,                          # Día
          capture.incident_date.month,                        # Mes
          capture.incident_date.year % 100,                   # Año (26, 25, etc)
          capture.estado,                                     # Estado
          capture.full_code,                                  # INEGI
          capture.municipio,                                  # Municipio
          capture.detenidos,                                  # Detenidos
          capture.organization&.name || capture.organizacion, # Organización
          capture.grupo_afiliado,                             # Grupo afiliado
          capture.nombre,                                     # Nombre
          capture.apellido_paterno,                           # Apellido Paterno
          capture.apellido_materno,                           # Apellido Materno
          capture.alias,                                      # Alias
          capture.genero,                                     # Género
          capture.edad,                                       # Edad
          capture.rol,                                        # Posición de liderazgo
          '',                                                 # Jefe regional (NO EXISTE)
          capture.sedena ? '1' : '',                          # SEDENA (1 o vacío)
          capture.semar ? '1' : '',                           # SEMAR
          capture.gn ? '1' : '',                              # GN
          capture.sscp ? '1' : '',                            # SSCP
          capture.fgr ? '1' : '',                             # FGR
          capture.ssp_estatal ? '1' : '',                     # SSP-Estatal
          capture.fge_pgj ? '1' : '',                         # FGE/PGJ
          capture.policia_municipal ? '1' : '',               # Policía municipal
          capture.otro ? '1' : '',                            # Otro
          '',                                                 # Resumen (NO EXISTE)
          capture.source_url,                                 # Fuente
          '',                                                 # Título nota (NO EXISTE)
          '',                                                 # Consultor (NO EXISTE)
          capture.status                                      # Status
        ]
      end
    end
  end

  def extract_hit_from_url(url, claude_key)
    begin
      # Fetch article content
      content = fetch_article_content(url)
      return { success: false, error: "No se pudo obtener contenido de la URL" } if content.blank?

      # Send to Claude for extraction
      user_message = "Extrae la siguiente información de esta nota de noticias:\n\n#{content}"
      extraction_prompt = <<~PROMPT.strip.freeze
        Eres un experto extrayendo información de notas de noticias sobre operativos de seguridad en México.

        Extrae EXACTAMENTE en formato JSON (y SOLO JSON, sin explicaciones):
        {
          "title": "Título de la nota",
          "date": "YYYY-MM-DD o null si no está disponible",
          "location": "Nombre del municipio o estado",
          "location_code": "Código del municipio (ej: 09009) o null",
          "should_create_hit": true o false (solo true si es nota relevante sobre operativos)
        }

        Reglas:
        - title: Extrae el título principal
        - date: Usa formato YYYY-MM-DD o null
        - location: Municipio y/o Estado si está disponible
        - should_create_hit: true SOLO si describe operativos, capturas o detenciones concretas
        - Responde ÚNICAMENTE el JSON, nada más
      PROMPT

      uri = URI("https://api.anthropic.com/v1/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri)
      req["x-api-key"] = claude_key
      req["anthropic-version"] = "2023-06-01"
      req["content-type"] = "application/json"
      req.body = {
        model: "claude-sonnet-4-6",
        max_tokens: 512,
        temperature: 0.0,
        system: extraction_prompt,
        messages: [{ role: "user", content: user_message }]
      }.to_json

      res = http.request(req)
      data = JSON.parse(res.body)

      if data["error"]
        error_msg = data["error"]["message"]
        return { success: false, error: error_msg }
      end

      response_text = data.dig("content", 0, "text")
      return { success: false, error: "Empty response from Claude" } if response_text.blank?

      # Parse JSON from Claude
      begin
        cleaned = response_text.gsub(/^```json\n?/, '').gsub(/\n?```$/, '').strip
        extraction = JSON.parse(cleaned)

        # Only create hit if Claude says it should be created
        if extraction["should_create_hit"] != true
          return { success: false, error: "Hit no relevante según análisis" }
        end

        # Try to find town by location name
        town = nil
        if extraction["location"].present?
          town = Town.where("name ILIKE ?", "%#{extraction['location']}%").first
        end

        # If no town found, try to find a default "Unknown" town or use first available town
        if town.blank?
          # Try to find a generic town
          town = Town.where("name ILIKE ?", "%desconocido%").first
          # If still not found, use the first town in the database
          town ||= Town.first
        end

        return { success: false, error: "No hay municipios registrados en la base de datos" } if town.blank?

        # Create hit record
        hit = Hit.new
        hit.title = extraction["title"]
        hit.date = extraction["date"] if extraction["date"].present?
        hit.link = url
        hit.town = town
        hit.legacy_id = (Hit.maximum(:legacy_id) || 0).to_i + 1

        if hit.save
          { success: true, hit_id: hit.id }
        else
          { success: false, error: hit.errors.full_messages.join(", ") }
        end
      rescue JSON::ParserError => e
        { success: false, error: "Error parsing Claude response: #{e.message}" }
      end
    rescue => e
      Rails.logger.error("[Agent#extract_hit_from_url] #{url} | #{e.class}: #{e.message}")
      { success: false, error: e.message }
    end
  end

  def fetch_article_content(url)
    begin
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.read_timeout = 10
      http.open_timeout = 5

      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

      res = http.request(req)
      return nil unless res.is_a?(Net::HTTPSuccess)

      # Extract text content from HTML
      doc = Nokogiri::HTML(res.body)
      doc.search('script, style').remove
      text = doc.text.gsub(/\s+/, ' ').strip
      text.first(5000)
    rescue => e
      Rails.logger.warn("[Agent#fetch_article_content] #{url} | #{e.class}: #{e.message}")
      nil
    end
  end
end
