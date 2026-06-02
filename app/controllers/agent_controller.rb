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
  REQUIRED_SNIPPET_WORDS = %w[deteni captur abati arrest operativo].freeze

  # ── Claude system prompt ──────────────────────────────────────────────────
  EXTRACTION_SYSTEM_PROMPT = <<~PROMPT.strip.freeze
    Eres un agente especializado en extraer información estructurada de notas periodísticas sobre operativos de seguridad en México.

    Recibes el texto completo de una nota. Tu tarea es extraer los datos y devolverlos como UNA o VARIAS líneas CSV según las reglas siguientes.

    REGLAS DE FILAS:
    - Una fila por cada persona detenida o abatida identificada por nombre
    - Si hay N personas sin nombre individual pero sí un total grupal, emite UNA sola fila con Detenidos=N y campos de nombre vacíos
    - Si hay mezcla (2 identificados + 3 anónimos): 2 filas individuales + 1 fila grupal con Detenidos=3

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
    18. Jefe regional (rol exacto: Líder / Operador / Jefe regional / Jefe de plaza / Jefe de célula / Jefe de sicarios / Jefe operativo / Sicario / Extorsionador / Traficante o distribuidor / Narcomenudista / Autoridad cooptada / Sin definir — vacío si desconocido)
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

    REGLAS CRÍTICAS:
    - Si la nota NO describe una detención o abatimiento concreto y confirmado, responde únicamente con: DESCARTAR
    - No inventes datos. Si algo no está en la nota, deja la celda vacía
    - Usa la fecha del operativo, no la de publicación. Si no hay fecha exacta, usa la de publicación
    - Para INEGI: 2 dígitos de estado + 3 de municipio (ej. Guadalajara = 14039). Si solo se menciona el estado, usa la clave de la capital
    - Nombres en Title Case
    - El alias usa punto y coma como separador interno
    - Para fuerzas: solo pon 1 si la nota las menciona explícitamente. Nunca inferir
    - Si la nota dice "elementos de seguridad" sin especificar fuerza, usa Otro=1
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

  def extract_batch
    body          = JSON.parse(request.raw_post)
    articles      = (body["articles"] || []).map(&:to_h)
    organizations = criminal_organizations

    claude_key = anthropic_api_key
    return render json: { error: "ANTHROPIC_API_KEY no configurada." }, status: :service_unavailable if claude_key.blank?

    results = []
    mutex   = Mutex.new

    threads = articles.map do |article|
      Thread.new do
        r = process_single_article(article, organizations, claude_key)
        mutex.synchronize { results << r }
      end
    end
    threads.each(&:join)

    # Preserve input order
    url_order = articles.map { |a| a["url"].to_s }
    sorted    = url_order.map { |url| results.find { |r| r[:url] == url } }.compact

    render json: { results: sorted }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PRIVATE
  # ═══════════════════════════════════════════════════════════════════════════
  private

  def process_single_article(article, organizations, claude_key)
    url     = article["url"].to_s
    title   = article["title"].to_s
    snippet = article["snippet"].to_s

    # Filter 1: excluded title keywords
    title_lower = I18n.transliterate(title.downcase)
    if EXCLUDED_TITLE_WORDS.any? { |w| title_lower.include?(w) }
      return { url: url, status: "discarded", reason: "titulo_excluido", csv_rows: [] }
    end

    # Filter 2: required snippet keywords
    snippet_lower = I18n.transliterate(snippet.downcase)
    unless REQUIRED_SNIPPET_WORDS.any? { |w| snippet_lower.include?(w) }
      return { url: url, status: "discarded", reason: "snippet_irrelevante", csv_rows: [] }
    end

    # Fetch article content
    content = fetch_article_content(url)
    if content.blank?
      return { url: url, status: "discarded", reason: "fetch_error", csv_rows: [] }
    end

    # Call Claude
    claude_response = call_claude_api(content, url, organizations, claude_key)
    if claude_response.nil?
      return { url: url, status: "error", reason: "claude_error", csv_rows: [] }
    end

    if claude_response.strip.upcase == "DESCARTAR"
      return { url: url, status: "discarded", reason: "claude_descartar", csv_rows: [] }
    end

    # Parse CSV rows — keep only lines that look like data rows
    rows = claude_response.strip.split("\n")
                          .map(&:strip)
                          .reject(&:empty?)
                          .reject { |r| r.start_with?("#") }
                          .select { |r| r.count(",") >= 5 }

    { url: url, status: "ok", reason: nil, csv_rows: rows }
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
    http.read_timeout = 45
    http.open_timeout = 10

    req = Net::HTTP::Post.new(uri)
    req["x-api-key"]         = claude_key
    req["anthropic-version"] = "2023-06-01"
    req["content-type"]      = "application/json"
    req.body = {
      model:      "claude-sonnet-4-20250514",
      max_tokens: 2048,
      system:     EXTRACTION_SYSTEM_PROMPT,
      messages:   [{ role: "user", content: user_message }]
    }.to_json

    res  = http.request(req)
    data = JSON.parse(res.body)
    data.dig("content", 0, "text")
  rescue => e
    Rails.logger.error("[Agent#claude_api] #{url}: #{e.class}: #{e.message}")
    nil
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
