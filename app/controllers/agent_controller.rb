class AgentController < ApplicationController
  before_action :authenticate_terrorist_access

  # ── Serper queries ────────────────────────────────────────────────────────
  SERPER_QUERIES = [
    "detienen líder cártel México",
    "capturan integrantes CJNG México operativo",
    "cae líder criminal célula México",
    "detenido integrante cártel Sinaloa",
    "caen integrantes crimen organizado México",
    "operativo detienen célula criminal México"
  ].freeze

  # ── Extraction filters ────────────────────────────────────────────────────
  EXCLUDED_TITLE_WORDS   = %w[opinión opinion analisis análisis columna editorial].freeze
  REQUIRED_SNIPPET_WORDS = %w[deteni captur abati arrest operativo asegurado asegura
                               aprehend imputad bloqueo narco cjng cartel cártel
                               elementos seguridad militares sedena fuerzas].freeze
  THEFT_WORDS            = %w[ladrón ladron autopartes].freeze
  THEFT_PHRASES          = ["robo de vehículo", "robo de vehiculo"].freeze
  CRIMEN_WORDS           = ["crimen organizado", "cartel", "cártel"].freeze
  EXCLUDED_DOMAINS       = %w[facebook.com].freeze

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
    5. INEGI (clave municipal de 5 dígitos: 2 dígitos estado + 3 dígitos municipio)
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

    MUNICIPIO E INEGI — clave municipal de 5 dígitos:

    Columna 5. INEGI (clave municipal: 2 dígitos estado + 3 dígitos municipio)
    Columna 6. Municipio (nombre del municipio mencionado en la nota)

    INSTRUCCIONES CRÍTICAS PARA INEGI:
    - Extrae del texto el NOMBRE del municipio y estado con máxima precisión
    - NO intentes NUNCA generar o adivinar el código INEGI
    - Si NO puedes identificar el municipio con certeza desde el texto de la nota, deja AMBOS campos (INEGI y Municipio) VACÍOS
    - El sistema backend validará el municipio contra la base de datos INEGI y completará el código automáticamente usando: estado + nombre del municipio
    - Si el municipio usa un alias común (ej: "Los Mochis" en lugar de "Ahome", "Cancún" en lugar de "Benito Juárez"), extrae el nombre que aparece en la nota tal cual está escrito
    - Si la nota menciona múltiples ubicaciones, extrae la ciudad/municipio donde ocurrió el operativo de detención, no donde fue publicada la nota

    VALIDACIÓN EN BACKEND:
    El código INEGI se calcula automáticamente por estos pasos:
    1. Busca por estado + nombre exacto del municipio
    2. Busca por estado + nombre normalizado (sin acentos, minúsculas)
    3. Busca por estado + alias del municipio (usando tabla county_aliases)
    4. Si no encuentra match confiable, deja el campo INEGI vacío

    REGLAS CRÍTICAS:
    - Si la nota NO describe una detención o abatimiento concreto y confirmado, responde únicamente con: DESCARTAR
    - No inventes datos. Si algo no está en la nota, deja la celda vacía
    - Edad: SOLO completa este campo si el texto menciona explícitamente un número de años de la persona detenida o abatida (ej. "de 34 años", "tiene 28 años"). Descripción física, apariencia o contexto NO son fuente válida para inferir edad. Si no hay número explícito, deja vacío.
    - Usa la fecha del operativo, no la de publicación. Si no hay fecha exacta, usa la de publicación
    - Nombres en Title Case
    - El alias usa punto y coma como separador interno
    - Para fuerzas: solo pon 1 si la nota las menciona explícitamente. Nunca inferir
    - Si la nota dice "elementos de seguridad" sin especificar fuerza, usa Otro=1

    VERIFICACIÓN FINAL ANTES DE EMITIR EL CSV:
    Antes de devolver tu respuesta, verifica que:
    1. Cada fila tiene exactamente 28 campos separados por coma
    2. Ningún campo numérico contiene texto
    3. Todo campo de texto que contenga comas está entre comillas dobles
    4. El campo Fuente en la posición 28 contiene una URL válida
    5. El campo Rol no está vacío y su valor pertenece al catálogo
    Si alguna fila no pasa esta verificación, corrígela. Si no puedes corregirla, omítela.
  PROMPT

  # ═══════════════════════════════════════════════════════════════════════════
  # ACTIONS
  # ═══════════════════════════════════════════════════════════════════════════

  def detentions
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

    results = articles.map { |article| process_single_article(article, organizations, claude_key) }
    render json: { results: results }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE
  # ═══════════════════════════════════════════════════════════════════════════
  private

  def process_single_article(article, organizations, claude_key)
    url     = article["url"].to_s
    title   = article["title"].to_s
    snippet = article["snippet"].to_s

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
    rows = claude_response.strip.split("\n")
                          .map(&:strip)
                          .reject(&:empty?)
                          .reject { |r| r.start_with?("#", "*", "-", " ") }
                          .reject { |r| r.start_with?("###CITA") }
                          .select { |r| r.match?(/\A\d{1,2},\d/) && r.count(",") >= 27 }

    # Validate INEGI codes in rows using robust method
    rows_with_validation = rows.map do |row|
      fields = row.split(",")
      estado = fields[3] if fields.length > 3
      inegi_code = fields[4] if fields.length > 4
      municipio = fields[5] if fields.length > 5

      validation_result = County.validate_inegi(inegi_code, municipio, estado)

      {
        row: row,
        inegi_code: inegi_code,
        municipio: municipio,
        estado: estado,
        validation: validation_result
      }
    end

    # When no rows parsed, include a truncated Claude response for diagnosis
    debug = rows.empty? ? claude_response.strip.first(1000) : nil

    {
      url: url,
      status: "ok",
      reason: nil,
      csv_rows: rows_with_validation.map { |r| r[:row] },
      inegi_validations: rows_with_validation,
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
      model:       "claude-sonnet-4-6",
      max_tokens:  2048,
      temperature: 0.0,
      system:      EXTRACTION_SYSTEM_PROMPT,
      messages:    [{ role: "user", content: user_message }]
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

  def criminal_organizations
    Sector.where(scian2: 98).last
          .organizations
          .where(active: true)
          .uniq
          .pluck(:name)
          .sort
  rescue => e
    Rails.logger.error("[Agent] criminal_organizations: #{e.message}")
    []
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
end
