#!/usr/bin/env ruby

# ============================================================
# OFAC Member Pipeline - Executor Maestro
# Documento de referencia: /OFAC_MEMBER_PIPELINE_ROBUSTO.md
# ============================================================
# ESTE ARCHIVO CONTIENE TODO EL CÓDIGO EJECUTABLE
# Cada PASO es una clase independiente
# ============================================================

require "set"
require "csv"
require "open-uri"
require "fileutils"
require "net/http"
require "json"

# Cargar servicio de resolución de apellidos compuestos
require_relative "../app/services/compound_lastname_resolver"

# ============================================================
# Módulo principal (definir primero)
# ============================================================

module OfacPipeline
  # ============================================================
  # TIMING HELPER (para profiling de ejecución)
  # ============================================================
  @timer_starts = {}
  @timings = {}

  def self.start_timer(label)
    @timer_starts[label] = Time.now
  end

  def self.end_timer(label)
    if @timer_starts[label]
      elapsed = Time.now - @timer_starts[label]
      @timings[label] = elapsed
      puts "   ⏱️  #{label}: #{elapsed.round(2)}s"
      elapsed
    end
  end

  def self.get_all_timings
    @timings
  end

  def self.load_anthropic_api_key
    key_file = File.expand_path("../../shared/config/anthropic_api_key", __dir__)
    ENV["ANTHROPIC_API_KEY"].presence ||
      (File.read(key_file).strip if File.exist?(key_file))
  end

  def self.load_serper_api_key
    key_file = File.expand_path("../../shared/config/serper_api_key", __dir__)
    ENV["SERPER_API_KEY"].presence ||
      (File.read(key_file).strip if File.exist?(key_file))
  end
end

class OfacPipeline::UpdateError < StandardError; end

# ============================================================
# PASO 1: Identificar Candidato OFAC Disponible
# ============================================================

class OfacPipeline::Step1
  def self.execute!
    begin
      puts "\n🔍 PASO 1: Identificar Candidato OFAC Disponible"
      puts "=" * 60

      OfacPipeline.start_timer("PASO 1 (Total)")

      # 1. Obtener lista OFAC sin match
      OfacPipeline.start_timer("Step1: Descargar OFAC SDN+ADD")
      ofac_list = extract_ofac_no_match_list
      OfacPipeline.end_timer("Step1: Descargar OFAC SDN+ADD")
      puts "📊 Total OFAC sin match: #{ofac_list.size}"

      # 2. Filtrar candidatos válidos (estructura: firstname + lastname1 + lastname2)
      OfacPipeline.start_timer("Step1: Filtrar estructura válida")
      valid_candidates = filter_valid_candidates(ofac_list)
      OfacPipeline.end_timer("Step1: Filtrar estructura válida")
      puts "✅ Candidatos con estructura válida: #{valid_candidates.size}"

      # 3. Excluir ya revisados en OfacCandidate
      OfacPipeline.start_timer("Step1: Filtrar OfacCandidate")
      available_candidates = filter_not_reviewed(valid_candidates)
      OfacPipeline.end_timer("Step1: Filtrar OfacCandidate")
      puts "📌 Candidatos NO revisados aún: #{available_candidates.size}"

      # 4. Retornar último (más reciente según orden OFAC)
      if available_candidates.empty?
        puts "\n❌ No hay candidatos OFAC disponibles"
        puts "   (Todos fueron revisados o no cumplen estructura válida)"
        return nil
      end

      candidate = available_candidates.last  # último = más reciente

      puts "\n" + "=" * 60
      puts "✅ CANDIDATO DISPONIBLE (PASO 1 OK):"
      puts "=" * 60
      puts "   OFAC Original:         #{candidate[:ofac_raw]}"
      puts "   Fullname (para BD):    #{candidate[:fullname]}"
      puts "   Components:"
      puts "     - Firstname: #{candidate[:firstname]}"
      puts "     - Lastname1: #{candidate[:lastname1]}"
      puts "     - Lastname2: #{candidate[:lastname2]}"
      puts "=" * 60

      OfacPipeline.end_timer("PASO 1 (Total)")

      return candidate

    rescue OfacPipeline::UpdateError => e
      puts "\n❌ ERROR EN PASO 1:"
      puts "   #{e.message}"
      exit 1
    rescue => e
      puts "\n❌ ERROR INESPERADO EN PASO 1:"
      puts "   #{e.class}: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    end
  end

  private

  # ============================================================
  # VALIDACIÓN 1: Obtener lista "SIN MATCH" de OFAC
  # ============================================================
  def self.extract_ofac_no_match_list
    puts "\n📥 Extrayendo lista OFAC sin match..."

    base_url = "https://www.treasury.gov/ofac/downloads"
    sdn_url = "#{base_url}/sdn.csv"
    add_url = "#{base_url}/add.csv"

    data_dir = Rails.root.join("tmp", "ofac_data")
    FileUtils.mkdir_p(data_dir)

    sdn_path = data_dir.join("sdn.csv")
    add_path = data_dir.join("add.csv")

    # Descargar SDN
    puts "   Descargando sdn.csv..."
    begin
      headers = { "User-Agent" => "Mozilla/5.0 (Ruby OFAC script)" }
      URI.open(sdn_url, headers.merge(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)) do |remote|
        File.binwrite(sdn_path, remote.read)
      end
    rescue => e
      raise OfacPipeline::UpdateError, "No se pudo descargar sdn.csv: #{e.message}"
    end

    # Descargar ADD
    puts "   Descargando add.csv..."
    begin
      headers = { "User-Agent" => "Mozilla/5.0 (Ruby OFAC script)" }
      URI.open(add_url, headers.merge(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)) do |remote|
        File.binwrite(add_path, remote.read)
      end
    rescue => e
      raise OfacPipeline::UpdateError, "No se pudo descargar add.csv: #{e.message}"
    end

    # 1. Identificar INDIVIDUALES en SDN
    individuals = {}
    CSV.foreach(sdn_path, headers: false, encoding: "bom|utf-8") do |row|
      next if row.nil?
      ent_num = row[0].to_s.strip
      name = row[1].to_s.strip
      type = row[2].to_s.strip.upcase
      next unless type == "INDIVIDUAL"
      individuals[ent_num] = { name: name }
    end

    puts "   📄 Individuales encontrados: #{individuals.size}"

    # 2. Identificar MÉXICO en ADD
    mexico_ent_nums = Set.new
    CSV.foreach(add_path, headers: false, encoding: "bom|utf-8") do |row|
      next if row.nil? || row.length < 5
      ent_num = row[0].to_s.strip
      country = row[4].to_s.strip
      next unless country == "Mexico" && individuals.key?(ent_num)
      mexico_ent_nums.add(ent_num)
    end

    puts "   🗺️  Individuales México: #{mexico_ent_nums.size}"

    # 3. Filtrar: solo México sin match en BD
    matched_ent_nums = Set.new
    Member.where(ofac_designation: true).where.not(ofac_ent_num: [nil, ""]).find_each do |m|
      matched_ent_nums.add(m.ofac_ent_num.to_s)
    end

    puts "   ✓ Members con match: #{matched_ent_nums.size}"

    no_match_list = mexico_ent_nums.reject { |ent_num| matched_ent_nums.include?(ent_num) }

    # 4. Retornar lista completa
    no_match_list.map do |ent_num|
      { ofac_name: individuals[ent_num][:name] }
    end
  end

  # ============================================================
  # VALIDACIÓN 2: Filtrar por estructura válida + Normalizar nombres
  # ============================================================
  def self.filter_valid_candidates(ofac_list)
    ofac_list.select do |candidate|
      name = candidate[:ofac_name]

      # Parsear: "LASTNAME, Firstname..."
      unless name.include?(",")
        next false
      end

      parts = name.split(",", 2)
      lastname_part = parts[0].strip
      firstname_part = parts[1].strip

      # Tokenizar
      lastname_tokens = lastname_part.split
      firstname_tokens = firstname_part.split

      # Validar estructura: lastname 2+, firstname 1+
      valid = lastname_tokens.size >= 2 && firstname_tokens.size >= 1

      if valid
        # NORMALIZACIÓN: transliterar acentos, capitalizar
        firstname_normalized = normalize_and_capitalize(firstname_part)
        lastname_normalized = normalize_and_capitalize(lastname_part)  # TODOS los apellidos

        # Enriquecer datos del candidato
        candidate[:firstname] = firstname_normalized

        # RESOLVER APELLIDOS COMPUESTOS (Nivel 1-4)
        resolved_lastnames = CompoundLastnameResolver.resolve(lastname_tokens, firstname_normalized)
        candidate[:lastname1] = resolved_lastnames[:lastname1]
        candidate[:lastname2] = resolved_lastnames[:lastname2]
        candidate[:lastname_resolution_source] = resolved_lastnames[:source]

        # Crear fullname en formato Member (equivalente a member.fullname)
        # IMPORTANTE: Incluir TODOS los apellidos, no solo los primeros 2
        candidate[:fullname] = "#{firstname_normalized} #{lastname_normalized}".strip

        # Normalizar para búsqueda (sin acentos, sin mayúsculas, sin Ñ)
        candidate[:fullname_search] = normalize_for_search(candidate[:fullname])

        # Guardar original OFAC como referencia (solo para display)
        candidate[:ofac_raw] = name
      end

      valid
    end
  end

  # ============================================================
  # VALIDACIÓN 3: Excluir ya revisados en OfacCandidate
  # ============================================================
  def self.filter_not_reviewed(valid_candidates)
    # Obtener todos los candidatos ya revisados (normalizados en Ruby)
    reviewed = OfacCandidate.pluck(:ofac_name).map { |name| normalize_for_search(name) }

    valid_candidates.reject do |candidate|
      # Comparar normalizando ambos lados en Ruby (transliterate maneja TODOS los acentos)
      reviewed.include?(candidate[:fullname_search])
    end
  end

  # ============================================================
  # Funciones de Normalización
  # ============================================================

  # Normaliza y capitaliza: transliterar + Title Case
  # "MARÍA GARCÍA" → "Maria Garcia"
  def self.normalize_and_capitalize(text)
    I18n.transliterate(text.to_s.strip).split.map(&:capitalize).join(" ")
  end

  # Normaliza para búsqueda: transliterar + lowercase
  # Elimina acentos, ñ, mayúsculas para comparación robusta
  # "Maria García" → "maria garcia"
  # "Marco VILLELA" → "marco villela"
  def self.normalize_for_search(text)
    I18n.transliterate(text.to_s.strip.downcase)
  end
end

# ============================================================
# PASO 2: Buscar Evidencia de Cartel y Crear Hit Provisional
# ============================================================

class OfacPipeline::Step2
  # ESTADOS DE MÉXICO (validación de ubicación)
  MEXICAN_STATES = {
    "Aguascalientes" => "AG", "Baja California" => "BC", "Baja California Sur" => "BS",
    "Campeche" => "CM", "Coahuila" => "CO", "Colima" => "CL", "Chiapas" => "CS",
    "Chihuahua" => "CH", "Ciudad de México" => "DF", "Durango" => "DG", "Guanajuato" => "GT",
    "Guerrero" => "GR", "Hidalgo" => "HG", "Jalisco" => "JL", "Estado de México" => "EM",
    "Michoacán" => "MI", "Morelos" => "MO", "Nayarit" => "NA", "Nuevo León" => "NL",
    "Oaxaca" => "OA", "Puebla" => "PB", "Querétaro" => "QT", "Quintana Roo" => "QR",
    "San Luis Potosí" => "SL", "Sinaloa" => "SI", "Sonora" => "SO", "Tabasco" => "TB",
    "Tamaulipas" => "TM", "Tlaxcala" => "TL", "Veracruz" => "VZ", "Yucatán" => "YU",
    "Zacatecas" => "ZA"
  }

  def self.execute!(candidate, include_cartel_keyword: true)
    begin
      search_label = include_cartel_keyword ? "con Cartel" : "SIN Cartel (Reintento)"
      puts "\n🔍 PASO 2: Buscar Evidencia de Cartel (#{search_label})"
      puts "=" * 60
      puts "Candidato: #{candidate[:fullname]}"
      puts "=" * 60

      OfacPipeline.start_timer("PASO 2 (Total)")

      # 1. Buscar en internet con WebSearch
      # Nota: fullname ya contiene firstname + TODOS los apellidos
      # Búsqueda: nombre COMPLETO exacto + palabra Cartel (si aplica)
      search_query = "\"#{candidate[:fullname]}\""
      search_query << " Cartel" if include_cartel_keyword
      puts "\n📡 Ejecutando búsqueda con WebSearch..."
      puts "   Query exacta: #{search_query}"

      OfacPipeline.start_timer("Step2: WebSearch (Serper API)")
      search_results = search_web(search_query)
      OfacPipeline.end_timer("Step2: WebSearch (Serper API)")

      if search_results.empty?
        puts "\n❌ No hay artículos disponibles para esta búsqueda"
        return nil
      end

      puts "\n📰 Resultados encontrados: #{search_results.size}"

      # 2. Iterar por resultados hasta encontrar uno válido con plain_text
      search_results.each_with_index do |result, idx|
        puts "\n[#{idx + 1}] Procesando: #{result[:title]}"

        # Validar link
        url = result[:url].to_s.strip
        next if url.blank?

        # Detectar si Hit es preexistente o nuevo
        existing_hit = Hit.find_by(link: url)
        was_existing_hit = existing_hit.present?

        if was_existing_hit
          # Reutilizar Hit existente
          hit = existing_hit
          puts "   ℹ️  Hit preexistente (ID: #{hit.id}) - Reutilizando"
        else
          # Crear Hit nuevo
          # Resolver ubicación
          date = Date.today
          title = result[:title][0, 255]

          location_result = resolve_location(result[:description].to_s, "")
          town_id = location_result[:town_id]
          location_info = location_result[:info]

          puts "   📍 Ubicación: #{location_info}"

          # Crear Hit provisional
          begin
            hit = Hit.create!(
              date: date,
              title: title,
              link: url,
              town_id: town_id,
              user_id: User.first&.id || 1,
              legacy_id: "OFAC_#{SecureRandom.hex(8).upcase}"
            )
            puts "   ✅ Hit creado (ID: #{hit.id})"
          rescue => e
            puts "   ❌ Error creando Hit: #{e.message}"
            next
          end
        end

        # Capturar plain_text (OBLIGATORIO)
        begin
          OfacPipeline.start_timer("Step2: HitSnapshotFetcher (capturar plain_text)")
          HitSnapshotFetcher.call!(hit, require_members: false)
          hit.reload
          OfacPipeline.end_timer("Step2: HitSnapshotFetcher (capturar plain_text)")

          if hit.plain_text.blank? || hit.plain_text.length < 800
            puts "   ❌ plain_text no válido (#{hit.plain_text&.length || 0} chars)"
            # NUNCA destruir un Hit preexistente
            if !was_existing_hit
              hit.destroy!
            end
            next
          end

          puts "   ✅ plain_text capturado (#{hit.plain_text.length} chars)"

          # VALIDACIÓN CRÍTICA: ¿Aparece el candidato en el texto?
          unless candidate_appears_in_text?(candidate, hit.plain_text)
            puts "   ❌ Candidato #{candidate[:fullname]} NO aparece en el plain_text"
            if !was_existing_hit
              hit.destroy!
            end
            next
          end

          puts "   ✅ Candidato validado en plain_text"

          puts "\n" + "=" * 60
          puts "✅ HIT VÁLIDO ENCONTRADO (PASO 2):"
          puts "=" * 60
          puts "   ID: #{hit.id}"
          puts "   Título: #{hit.title}"
          puts "   Fecha: #{hit.date} (provisional)"
          puts "   Ubicación: #{location_info} (provisional)"
          puts "   Link: #{hit.link}"
          puts "\n📄 PLAIN_TEXT CAPTURADO (primeros 500 chars):"
          puts "=" * 60
          puts hit.plain_text[0, 500]
          puts "..."
          puts "=" * 60

          OfacPipeline.end_timer("PASO 2 (Total)")

          return hit

        rescue => e
          puts "   ❌ Error capturando plain_text: #{e.message}"
          # NUNCA destruir un Hit preexistente
          if hit.persisted? && !was_existing_hit
            hit.destroy!
          end
          next
        end
      end

      # Si llegó aquí: ningún artículo fue válido
      puts "\n❌ No se pudo crear Hit válido con ningún resultado"
      nil

    rescue OfacPipeline::UpdateError => e
      puts "\n❌ ERROR EN PASO 2:"
      puts "   #{e.message}"
      nil
    rescue => e
      puts "\n❌ ERROR INESPERADO EN PASO 2:"
      puts "   #{e.class}: #{e.message}"
      puts e.backtrace.first(5)
      nil
    end
  end

  private

  # Buscar en internet usando WebSearch (herramienta integrada en Claude Code)
  # Buscar en Serper (Google Search API)
  def self.search_web(query)
    api_key = OfacPipeline.load_serper_api_key
    unless api_key
      raise OfacPipeline::UpdateError, "SERPER_API_KEY no configurada en .env o archivo"
    end

    begin
      uri = URI("https://google.serper.dev/news")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      http.open_timeout = 5

      req = Net::HTTP::Post.new(uri)
      req["X-API-KEY"] = api_key
      req["Content-Type"] = "application/json"
      req.body = {
        q: query,
        # tbs removido: permite búsqueda sin límite de tiempo (10+ años)
        gl: "mx",        # México
        hl: "es",        # Español
        num: 10          # 10 resultados
      }.to_json

      puts "\n   📡 Enviando request a Serper..."
      puts "   URL: #{uri}"
      puts "   Body: #{req.body}"

      res = http.request(req)

      puts "\n   📍 Response Status: #{res.code}"
      puts "   📍 Response Body (COMPLETO):"
      puts "   #{res.body}"

      data = JSON.parse(res.body)

      puts "\n   📊 Datos parseados:"
      puts "   Total keys: #{data.keys}"
      puts "   news key present?: #{data.key?("news")}"
      puts "   news value: #{data["news"].inspect[0..200]}"

      if data["news"].is_a?(Array)
        puts "   ✅ News es un Array con #{data["news"].size} resultados"
        data["news"].map do |article|
          {
            title: article["title"],
            url: article["link"],
            description: article["snippet"]
          }
        end
      else
        puts "   ⚠️  News no es un Array o está vacío"
        []
      end
    rescue => e
      puts "\n   ❌ Exception: #{e.class}: #{e.message}"
      raise OfacPipeline::UpdateError, "Error en búsqueda Serper: #{e.message}"
    end
  end

  # PASO 3: Extraer fecha real del artículo usando Claude
  # IMPORTANTE: Siempre intenta extraer la fecha. Si falla, el Hit mantendrá Date.today como fallback
  def self.extract_date_with_claude(plain_text)
    begin
      api_key = OfacPipeline.load_anthropic_api_key
      unless api_key
        puts "     ⚠️  ANTHROPIC_API_KEY no configurada, retorna nil para fallback"
        return nil
      end

      # Limpiar HTML y pasar 2000 caracteres (suficiente para fechas)
      clean_text = clean_html_from_text(plain_text)
      text_to_analyze = clean_text[0, 2000]

      user_message = "Extrae la fecha de publicación de este artículo. Retorna SOLO la fecha en formato YYYY-MM-DD (ej: 2026-09-29). Si no la encuentras, retorna solo: INVALID\n\n#{text_to_analyze}"

      uri = URI("https://api.anthropic.com/v1/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri)
      req["x-api-key"] = api_key
      req["anthropic-version"] = "2023-06-01"
      req["content-type"] = "application/json"
      req.body = {
        model: "claude-sonnet-4-6",
        max_tokens: 20,
        messages: [{ role: "user", content: user_message }]
      }.to_json

      res = http.request(req)
      res_body = JSON.parse(res.body)
      puts "     📡 Claude response code: #{res.code}"
      puts "     📡 Claude response keys: #{res_body.keys.inspect}"

      if res.code.to_i != 200
        puts "     ❌ Claude error (#{res.code}): #{res_body.dig("error", "message")}"
        return nil
      end

      content = res_body["content"]
      # Buscar el bloque de texto (puede haber múltiples bloques si usa extended thinking)
      text_block = content.is_a?(Array) ? content.find { |c| c["type"] == "text" } : nil
      date_str = text_block&.dig("text").to_s.strip

      # Limpiar markdown si está presente
      date_str_clean = date_str.gsub(/^\*\*/, '').gsub(/\*\*$/, '').strip

      puts "     📝 Claude text_block found: #{!text_block.nil?}, date_str: '#{date_str_clean}' (length: #{date_str_clean.length})"

      # Validar formato YYYY-MM-DD
      if date_str_clean.blank? || date_str_clean == "INVALID" || !date_str_clean.match?(/^\d{4}-\d{2}-\d{2}$/)
        puts "     ⚠️  Claude retornó inválido: '#{date_str_clean}'"
        return nil
      end

      # Parsear y validar rango de fechas
      extracted = Date.parse(date_str_clean)
      today = Date.today
      one_year_ago = today - 365

      # Validar que no sea fecha futura ni muy antigua
      if extracted > today || extracted < one_year_ago
        puts "     ⚠️  Fecha fuera de rango: #{extracted}"
        return nil
      end

      extracted

    rescue => e
      puts "     ❌ Error con Claude: #{e.class} #{e.message}"
      nil
    end
  end

  # Limpiar HTML del plain_text
  def self.clean_html_from_text(text)
    # Remover tags HTML
    clean = text.gsub(/<[^>]*>/m, '')
    # Normalizar espacios múltiples
    clean = clean.gsub(/\s+/, ' ')
    # Remover patrones de navegación comunes
    clean = clean.gsub(/^(Menu|Mostrar|Estados|Secciones|Suplementos|Abrir en|Opens in|Share|Compartir).*?(?=\n|\s{2,})/i, '')
    clean.strip
  end

  # PASO 4: Extraer ubicación real del artículo usando Claude
  def self.extract_location_with_claude(plain_text, current_town_id)
    begin
      api_key = OfacPipeline.load_anthropic_api_key
      unless api_key
        puts "     ⚠️  ANTHROPIC_API_KEY no configurada"
        return current_town_id
      end

      # Limpiar HTML y pasar 3000 caracteres para máxima precisión
      clean_text = clean_html_from_text(plain_text)
      text_to_analyze = clean_text[0, 3000]

      user_message = "Extrae el Estado y Municipio mexicano mencionados en este artículo. Retorna JSON: {\"state\": \"nombre\" | null, \"county\": \"nombre\" | null}\n\n#{text_to_analyze}"

      uri = URI("https://api.anthropic.com/v1/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri)
      req["x-api-key"] = api_key
      req["anthropic-version"] = "2023-06-01"
      req["content-type"] = "application/json"
      req.body = {
        model: "claude-sonnet-4-6",
        max_tokens: 50,
        messages: [{ role: "user", content: user_message }]
      }.to_json

      res = http.request(req)
      res_body = JSON.parse(res.body)

      if res.code.to_i != 200
        puts "     ❌ Claude error (#{res.code}): #{res_body.dig("error", "message")}"
        return current_town_id
      end

      content = res_body["content"]
      puts "     📝 Content blocks: #{content.map { |c| c["type"] }.inspect}"

      # Encontrar bloque de texto
      text_block = nil
      if content.is_a?(Array)
        text_block = content.find { |c| c["type"] == "text" }
      end

      location_json = text_block&.dig("text").to_s.strip

      puts "     📝 Claude location response: #{location_json[0..100] rescue 'ERROR'}"
      puts "     📝 Text block found: #{!text_block.nil?}"

      if location_json.blank?
        puts "     ⚠️  Claude retornó respuesta vacía para ubicación"
        return current_town_id
      end

      # Limpiar markdown si está presente
      location_json_clean = location_json.gsub(/^```json\n?/, '').gsub(/\n?```$/, '').strip

      location_data = JSON.parse(location_json_clean)
      state_name = location_data["state"]
      county_name = location_data["county"]

      # CRITERIO 1: Sin identificación → CDMX fallback
      if state_name.blank? && county_name.blank?
        puts "     ⚠️  Claude no identificó ubicación, usando CDMX fallback"
        return resolve_location_cdmx_town_id
      end

      # Buscar State en BD
      state_obj = State.find_by("LOWER(name) = ?", state_name.downcase) if state_name.present?

      if state_obj.nil?
        puts "     ⚠️  State '#{state_name}' no existe en BD, usando CDMX fallback"
        return resolve_location_cdmx_town_id
      end

      # CRITERIO 2: Solo Estado identificado
      if county_name.blank?
        puts "     ✅ Estado identificado SOLO: #{state_obj.name}"
        sin_def_county = state_obj.counties.find_by(name: "Sin definir")
        town = sin_def_county&.towns&.find_by(name: "Sin definir")

        if town
          puts "     ✅ Town resuelto: #{town.name} (#{sin_def_county.name}, #{state_obj.name})"
          return town.id
        else
          puts "     ❌ No se pudo encontrar Town en Sin definir, fallback CDMX"
          return resolve_location_cdmx_town_id
        end
      end

      # CRITERIO 3: Estado Y Municipio identificados
      if county_name.present?
        county_obj = state_obj.counties.find_by("LOWER(name) = ?", county_name.downcase)

        if county_obj
          puts "     ✅ Estado Y Municipio identificados: #{county_obj.name}, #{state_obj.name}"
          town = county_obj.towns.find_by(name: "Sin definir")

          if town
            puts "     ✅ Town resuelto: #{town.name} (#{county_obj.name}, #{state_obj.name})"
            return town.id
          else
            puts "     ⚠️  Town 'Sin definir' no existe en #{county_obj.name}, fallback CDMX"
            return resolve_location_cdmx_town_id
          end
        else
          # Municipio no existe → usar "Sin definir" del State
          puts "     ⚠️  Municipio '#{county_name}' no existe en #{state_obj.name}, usando Sin definir"
          sin_def_county = state_obj.counties.find_by(name: "Sin definir")
          town = sin_def_county&.towns&.find_by(name: "Sin definir")

          if town
            puts "     ✅ Town resuelto: #{town.name} (Sin definir, #{state_obj.name})"
            return town.id
          else
            puts "     ⚠️  No se pudo encontrar Town, fallback CDMX"
            return resolve_location_cdmx_town_id
          end
        end
      end

      # Fallback si todo falla
      puts "     ⚠️  No se pudo resolver ubicación, usando CDMX fallback"
      resolve_location_cdmx_town_id

    rescue JSON::ParserError => e
      puts "     ❌ Error parsing Claude response: #{e.message}"
      current_town_id
    rescue => e
      puts "     ❌ Error con Claude: #{e.class} #{e.message}"
      current_town_id
    end
  end

  # Helper para CDMX fallback
  def self.resolve_location_cdmx_town_id
    cdmx = State.find_by("LOWER(name) = ?", "ciudad de méxico")
    sin_def_county = cdmx&.counties&.find_by(name: "Sin definir")
    town = sin_def_county&.towns&.find_by(name: "Sin definir")
    town&.id
  end

  # Resolver ubicación según reglas obligatorias
  def self.resolve_location(description, content)
    text = "#{description} #{content}".downcase

    # Buscar estado mexicano en el texto
    identified_state = nil
    MEXICAN_STATES.each do |state_name, code|
      if text.include?(state_name.downcase)
        identified_state = state_name
        break
      end
    end

    # Buscar municipios dentro del estado identificado (si aplica)
    identified_county = nil
    identified_state_obj = nil

    if identified_state
      identified_state_obj = State.find_by("LOWER(name) = ?", identified_state.downcase)

      if identified_state_obj
        # Buscar municipios del estado
        identified_state_obj.counties.each do |county|
          if text.include?(county.name.downcase)
            identified_county = county
            break
          end
        end
      end
    end

    # RESOLVER SEGÚN REGLAS OBLIGATORIAS
    if identified_state_obj
      if identified_county
        # Estado Y Municipio identificados → Town "Sin definir" del municipio
        town = identified_county.towns.find_by(name: "Sin definir")
        info = "#{identified_county.name}, #{identified_state_obj.name}"
      else
        # SOLO Estado identificado → Town "Sin definir" del Municipio "Sin definir" del Estado
        sin_def_county = identified_state_obj.counties.find_by(name: "Sin definir")
        town = sin_def_county&.towns&.find_by(name: "Sin definir")
        info = "Sin definir, #{identified_state_obj.name}"
      end
    else
      # NO se identificó nada OR es extranjero → CDMX
      cdmx = State.find_by("LOWER(name) = ?", "ciudad de méxico")
      sin_def_county = cdmx&.counties&.find_by(name: "Sin definir")
      town = sin_def_county&.towns&.find_by(name: "Sin definir")
      info = "Sin definir, Ciudad de México (fallback)"
    end

    # Validar que se encontró un town
    unless town
      raise OfacPipeline::UpdateError, "No se pudo resolver town para ubicación"
    end

    { town_id: town.id, info: info }
  end

  # ============================================================
  # Validación: ¿Aparece el candidato en el plain_text?
  # ============================================================
  def self.candidate_appears_in_text?(candidate, plain_text)
    normalized_text = normalize_for_search(plain_text)

    firstname_norm = normalize_for_search(candidate[:firstname])
    lastname1_norm = normalize_for_search(candidate[:lastname1])

    # Ambos (firstname Y lastname1) deben aparecer
    firstname_found = normalized_text.include?(firstname_norm)
    lastname1_found = normalized_text.include?(lastname1_norm)

    firstname_found && lastname1_found
  end

  def self.normalize_for_search(text)
    I18n.transliterate(text.to_s.strip.downcase)
  end

  # Obtener API Key de múltiples ubicaciones (como en diagnose_claude_api.rb)
  def self.get_anthropic_api_key
    api_key_env = OfacPipeline.load_anthropic_api_key
    api_key_creds = Rails.application.credentials.dig(:anthropic, :api_key)
    api_key_file = begin
      key_file = Rails.root.join("..", "..", "shared", "config", "anthropic_api_key").expand_path
      File.read(key_file).strip if File.exist?(key_file)
    rescue
      nil
    end
    api_key_env || api_key_creds || api_key_file
  end
end

# ============================================================
# PASO 3: Extraer Fecha con Claude (INDEPENDIENTE)
# ============================================================

class OfacPipeline::Step3
  def self.execute!(hit)
    begin
      puts "\n🤖 PASO 3: Extrayendo fecha con Claude..."
      puts "=" * 60

      OfacPipeline.start_timer("PASO 3 (Total)")
      OfacPipeline.start_timer("Step3: Claude API call (extract date)")
      extracted_date = extract_date_with_claude(hit.plain_text)
      OfacPipeline.end_timer("Step3: Claude API call (extract date)")

      if extracted_date
        hit.update!(date: extracted_date)
        puts "✅ Fecha extraída por Claude: #{extracted_date}"
      else
        fallback_date = Date.today
        hit.update!(date: fallback_date)
        puts "⚠️  Claude no pudo extraer fecha, usando fallback Date.today: #{fallback_date}"
      end

      OfacPipeline.end_timer("PASO 3 (Total)")
      { date: hit.date }
    rescue => e
      puts "\n❌ ERROR EN PASO 3:"
      puts "   #{e.class}: #{e.message}"
      nil
    end
  end

  private

  def self.extract_date_with_claude(plain_text)
    begin
      api_key = OfacPipeline.load_anthropic_api_key
      unless api_key
        puts "⚠️  ANTHROPIC_API_KEY no configurada"
        return nil
      end

      clean_text = clean_html_from_text(plain_text)
      text_to_analyze = clean_text[0, 2000]

      user_message = "Extrae la fecha de publicación de este artículo. Retorna SOLO la fecha en formato YYYY-MM-DD (ej: 2026-09-29). Si no la encuentras, retorna solo: INVALID\n\n#{text_to_analyze}"

      uri = URI("https://api.anthropic.com/v1/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri)
      req["x-api-key"] = api_key
      req["anthropic-version"] = "2023-06-01"
      req["content-type"] = "application/json"
      req.body = {
        model: "claude-sonnet-4-6",
        max_tokens: 20,
        messages: [{ role: "user", content: user_message }]
      }.to_json

      res = http.request(req)
      res_body = JSON.parse(res.body)

      if res.code.to_i != 200
        return nil
      end

      content = res_body["content"]
      text_block = content.is_a?(Array) ? content.find { |c| c["type"] == "text" } : nil
      date_str = text_block&.dig("text").to_s.strip
      date_str_clean = date_str.gsub(/^\*\*/, '').gsub(/\*\*$/, '').strip

      if date_str_clean.blank? || date_str_clean == "INVALID" || !date_str_clean.match?(/^\d{4}-\d{2}-\d{2}$/)
        return nil
      end

      extracted = Date.parse(date_str_clean)
      today = Date.today
      one_year_ago = today - 365

      if extracted > today || extracted < one_year_ago
        return nil
      end

      extracted
    rescue => e
      nil
    end
  end

  def self.clean_html_from_text(text)
    clean = text.gsub(/<[^>]*>/m, '')
    clean = clean.gsub(/\s+/, ' ')
    clean = clean.gsub(/^(Menu|Mostrar|Estados|Secciones|Suplementos|Abrir en|Opens in|Share|Compartir).*?(?=\n|\s{2,})/i, '')
    clean.strip
  end
end

# ============================================================
# PASO 4: Extraer Ubicación con Claude (INDEPENDIENTE)
# ============================================================

class OfacPipeline::Step4
  def self.execute!(hit)
    begin
      puts "\n🤖 PASO 4: Extrayendo ubicación con Claude..."
      puts "=" * 60

      OfacPipeline.start_timer("PASO 4 (Total)")
      OfacPipeline.start_timer("Step4: Claude API call (extract location)")
      updated_town_id = extract_location_with_claude(hit.plain_text, hit.town_id)
      OfacPipeline.end_timer("Step4: Claude API call (extract location)")

      if updated_town_id && updated_town_id != hit.town_id
        hit.update!(town_id: updated_town_id)
        hit.reload
        puts "✅ Ubicación actualizada"
      else
        puts "⚠️  Ubicación sin cambios o error"
      end

      OfacPipeline.end_timer("PASO 4 (Total)")
      { town_id: hit.town_id }
    rescue => e
      puts "\n❌ ERROR EN PASO 4:"
      puts "   #{e.class}: #{e.message}"
      nil
    end
  end

  private

  def self.extract_location_with_claude(plain_text, current_town_id)
    begin
      api_key = OfacPipeline.load_anthropic_api_key
      unless api_key
        return current_town_id
      end

      clean_text = clean_html_from_text(plain_text)
      text_to_analyze = clean_text[0, 3000]

      user_message = "Extrae el Estado y Municipio mexicano mencionados en este artículo. Retorna JSON: {\"state\": \"nombre\" | null, \"county\": \"nombre\" | null}\n\n#{text_to_analyze}"

      uri = URI("https://api.anthropic.com/v1/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri)
      req["x-api-key"] = api_key
      req["anthropic-version"] = "2023-06-01"
      req["content-type"] = "application/json"
      req.body = {
        model: "claude-sonnet-4-6",
        max_tokens: 50,
        messages: [{ role: "user", content: user_message }]
      }.to_json

      res = http.request(req)
      res_body = JSON.parse(res.body)

      if res.code.to_i != 200
        return current_town_id
      end

      content = res_body["content"]
      text_block = nil
      if content.is_a?(Array)
        text_block = content.find { |c| c["type"] == "text" }
      end

      location_json = text_block&.dig("text").to_s.strip

      if location_json.blank?
        return current_town_id
      end

      location_json_clean = location_json.gsub(/^```json\n?/, '').gsub(/\n?```$/, '').strip
      location_data = JSON.parse(location_json_clean)
      state_name = location_data["state"]
      county_name = location_data["county"]

      if state_name.blank? && county_name.blank?
        return resolve_location_cdmx_town_id
      end

      state_obj = State.find_by("LOWER(name) = ?", state_name.downcase) if state_name.present?

      if state_obj.nil?
        return resolve_location_cdmx_town_id
      end

      if county_name.blank?
        sin_def_county = state_obj.counties.find_by(name: "Sin definir")
        town = sin_def_county&.towns&.find_by(name: "Sin definir")
        return town.id if town
        return resolve_location_cdmx_town_id
      end

      if county_name.present?
        county_obj = state_obj.counties.find_by("LOWER(name) = ?", county_name.downcase)

        if county_obj
          town = county_obj.towns.find_by(name: "Sin definir")
          return town.id if town
        else
          sin_def_county = state_obj.counties.find_by(name: "Sin definir")
          town = sin_def_county&.towns&.find_by(name: "Sin definir")
          return town.id if town
        end
      end

      resolve_location_cdmx_town_id
    rescue JSON::ParserError => e
      current_town_id
    rescue => e
      current_town_id
    end
  end

  def self.resolve_location_cdmx_town_id
    cdmx = State.find_by("LOWER(name) = ?", "ciudad de méxico")
    sin_def_county = cdmx&.counties&.find_by(name: "Sin definir")
    town = sin_def_county&.towns&.find_by(name: "Sin definir")
    town&.id
  end

  def self.clean_html_from_text(text)
    clean = text.gsub(/<[^>]*>/m, '')
    clean = clean.gsub(/\s+/, ' ')
    clean = clean.gsub(/^(Menu|Mostrar|Estados|Secciones|Suplementos|Abrir en|Opens in|Share|Compartir).*?(?=\n|\s{2,})/i, '')
    clean.strip
  end
end

# ============================================================
# PASO 5: Validar Vinculación con Cartel en Catálogo
# ============================================================

class OfacPipeline::Step6
  # Validación final antes de guardar Member
  def self.validate_and_retry(candidate, hit, organization_id, was_existing_hit: false, attempt: 1)
    begin
      puts "\n" + "=" * 80
      puts "✅ PASO 6: VALIDACIÓN FINAL"
      puts "=" * 80
      puts "Intento: #{attempt}/2"

      # Verificar los 4 requisitos críticos
      validation_errors = []

      # 1. Verificar plain_text
      if hit.plain_text.blank? || hit.plain_text.length < 800
        validation_errors << "NO_HIT_FOUND (plain_text insuficiente: #{hit.plain_text&.length || 0} chars)"
      end

      # 2. Verificar fecha
      if hit.date.blank? || hit.date > Date.today
        validation_errors << "MISSING_DATE (fecha inválida: #{hit.date.inspect})"
      end

      # 3. Verificar ubicación
      if hit.town_id.blank?
        validation_errors << "MISSING_LOCATION (ubicación no definida)"
      end

      # 4. Verificar organización criminal
      if organization_id.blank?
        validation_errors << "NO_CARTEL_MATCH (no se identificó organización)"
      end

      # Si todo está bien → Éxito
      if validation_errors.empty?
        puts "\n✅ VALIDACIÓN EXITOSA - Todos los requisitos cumplidos:"
        puts "   ✓ plain_text: #{hit.plain_text.length} caracteres"
        puts "   ✓ Fecha: #{hit.date}"
        puts "   ✓ Ubicación: #{hit.town&.county&.name}, #{hit.town&.county&.state&.name}"
        puts "   ✓ Organización ID: #{organization_id}"
        puts "\n→ Procediendo a PASO 7"
        return {
          success: true,
          candidate: candidate,
          hit: hit,
          organization_id: organization_id
        }
      end

      # Si falló y es el primer intento → Reintentar
      if attempt == 1
        puts "\n⚠️  VALIDACIÓN FALLIDA EN INTENTO 1"
        puts "   Problemas encontrados:"
        validation_errors.each { |e| puts "     - #{e}" }

        # NUNCA destruir un Hit preexistente
        if was_existing_hit
          puts "\n⚠️  Hit preexistente no cumple requisitos, pasando al siguiente resultado"
          return { success: false, candidate_name: candidate[:fullname], primary_cause: "NO_VALID_HIT", attempt: 1, was_existing: true }
        else
          puts "\n🔄 Destruyendo Hit nuevo e intentando nueva búsqueda (sin palabra 'Cartel')..."
          hit.destroy!
          # REINTENTAR: Búsqueda sin "Cartel"
          return retry_search(candidate, attempt: 2)
        end
      else
        # Si falló en el segundo intento → Destruir Hit y terminar
        puts "\n❌ VALIDACIÓN FALLIDA EN INTENTO 2 - FLUJO TERMINADO"
        puts "=" * 80
        puts "❌ NO SE PUDO PROCESAR A #{candidate[:fullname].upcase}"
        puts "=" * 80

        primary_cause = validation_errors.first.split("(").first
        all_causes = validation_errors.map { |e| e.split("(").first }.uniq

        puts "\nCausas de fracaso:"
        all_causes.each { |c| puts "  • #{c}" }

        puts "\nDetalles:"
        validation_errors.each { |e| puts "  • #{e}" }

        # NUNCA destruir un Hit preexistente
        if !was_existing_hit && hit.persisted?
          hit.destroy!
          puts "\n🗑️  Hit destruido (ID: #{hit.id})"
        elsif was_existing_hit
          puts "\n ℹ️  Hit preexistente no fue destruido (preservando información)"
        end

        return { success: false, candidate_name: candidate[:fullname], primary_cause: primary_cause, all_causes: all_causes }
      end

    rescue => e
      puts "\n❌ ERROR TÉCNICO EN PASO 6:"
      puts "   #{e.class}: #{e.message}"

      if attempt == 1
        puts "\n🔄 Retentando con búsqueda sin 'Cartel'..."
        # NUNCA destruir un Hit preexistente
        if !was_existing_hit && hit.persisted?
          hit.destroy!
        end
        return retry_search(candidate, attempt: 2)
      else
        return { success: false, candidate_name: candidate[:fullname], primary_cause: "TECHNICAL_ERROR", error: "#{e.class}: #{e.message}" }
      end
    end
  end

  def self.retry_search(candidate, attempt: 2)
    begin
      puts "\n" + "=" * 80
      puts "🔍 REINTENTAN DO: Búsqueda sin palabra 'Cartel' (Intento #{attempt}/2)"
      puts "=" * 80
      puts "Candidato: #{candidate[:fullname]}"

      # PASO 2 REINTENTADO: Búsqueda sin "Cartel"
      search_query = "\"#{candidate[:fullname]}\""
      puts "\n📡 Ejecutando búsqueda con WebSearch (SIN 'Cartel')..."
      puts "   Query: #{search_query}"

      search_results = OfacPipeline::Step2.search_web(search_query)

      if search_results.empty?
        puts "\n❌ No hay artículos disponibles en el reintento"
        return { success: false, candidate_name: candidate[:fullname], primary_cause: "NO_HIT_FOUND", attempt: 2 }
      end

      puts "\n📰 Resultados encontrados: #{search_results.size}"

      # Procesar resultados (igual que PASO 2 original)
      hit = nil
      search_results.each_with_index do |result, idx|
        puts "\n[#{idx + 1}] Procesando: #{result[:title]}"

        url = result[:url].to_s.strip
        next if url.blank?

        # Detectar si Hit es preexistente o nuevo (REINTENTO)
        existing_hit = Hit.find_by(link: url)
        was_existing_hit_reintento = existing_hit.present?

        if was_existing_hit_reintento
          # Reutilizar Hit existente
          hit = existing_hit
          puts "   ℹ️  Hit preexistente (ID: #{hit.id}) - Reutilizando"
        else
          # Crear Hit nuevo
          begin
            hit = Hit.create!(
              date: Date.today,
              title: result[:title][0, 255],
              link: url,
              town_id: OfacPipeline::Step2.resolve_location(result[:description].to_s, "")[:town_id],
              user_id: User.first&.id || 1,
              legacy_id: "OFAC_#{SecureRandom.hex(8).upcase}"
            )
            puts "   ✅ Hit creado (ID: #{hit.id})"
          rescue => e
            puts "   ❌ Error: #{e.message}"
            next
          end
        end

        # Capturar plain_text
        begin
          HitSnapshotFetcher.call!(hit, require_members: false)
          hit.reload

          if hit.plain_text.blank? || hit.plain_text.length < 800
            puts "   ❌ plain_text no válido"
            # NUNCA destruir un Hit preexistente
            if !was_existing_hit_reintento
              hit.destroy!
            end
            next
          end

          puts "   ✅ plain_text capturado"

          # VALIDACIÓN CRÍTICA: ¿Aparece el candidato en el texto?
          unless OfacPipeline::Step2.candidate_appears_in_text?(candidate, hit.plain_text)
            puts "   ❌ Candidato #{candidate[:fullname]} NO aparece en el plain_text"
            if !was_existing_hit_reintento
              hit.destroy!
            end
            next
          end

          puts "   ✅ Candidato validado en plain_text"

          # PASO 3 REINTENTADO
          extracted_date = OfacPipeline::Step2.extract_date_with_claude(hit.plain_text)
          hit.update!(date: extracted_date || Date.today)
          puts "   ✅ Fecha extraída"

          # PASO 4 REINTENTADO
          updated_town_id = OfacPipeline::Step2.extract_location_with_claude(hit.plain_text, hit.town_id)
          hit.update!(town_id: updated_town_id) if updated_town_id
          puts "   ✅ Ubicación extraída"

          # PASO 5 REINTENTADO
          cartel_match = OfacPipeline::Step5.execute!(hit)
          organization_id = cartel_match[:organization_id] if cartel_match && cartel_match[:found]

          # PASO 6 REINTENTADO (Validación)
          return validate_and_retry(candidate, hit, organization_id, was_existing_hit: was_existing_hit_reintento, attempt: 2)

        rescue => e
          puts "   ❌ Error procesando: #{e.message}"
          # NUNCA destruir un Hit preexistente
          if hit.persisted? && !was_existing_hit_reintento
            hit.destroy!
          end
          next
        end
      end

      # No se encontró Hit válido en el reintento
      puts "\n❌ No se pudo encontrar Hit válido en el reintento"
      return { success: false, candidate_name: candidate[:fullname], primary_cause: "NO_HIT_FOUND", attempt: 2 }

    rescue => e
      puts "\n❌ ERROR EN REINTENTO: #{e.class} #{e.message}"
      return { success: false, candidate_name: candidate[:fullname], primary_cause: "TECHNICAL_ERROR", attempt: 2 }
    end
  end
end

class OfacPipeline::Step5
  # Obtener catálogo de cárteles (Sector SCIAN 98)
  def self.get_cartel_catalog
    Sector.where(scian2: 98).last&.organizations&.where(active: true)&.uniq || []
  end

  # Normalizar nombre para comparación
  # Transliteración + lowercase + remover puntuación y espacios múltiples
  def self.normalize_name(text)
    I18n.transliterate(text.to_s.strip.downcase)
      .gsub(/[^a-z0-9\s]/, '')
      .gsub(/\s+/, ' ')
      .strip
  end

  # Levenshtein distance para fuzzy matching (variaciones ortográficas)
  def self.levenshtein_distance(str1, str2)
    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }

    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }

    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = str1[i-1] == str2[j-1] ? 0 : 1
        matrix[i][j] = [
          matrix[i-1][j] + 1,
          matrix[i][j-1] + 1,
          matrix[i-1][j-1] + cost
        ].min
      end
    end

    matrix[str1.length][str2.length]
  end

  # Calcular puntuación de similitud (0-100)
  def self.similarity_score(text1, text2)
    norm1 = normalize_name(text1)
    norm2 = normalize_name(text2)

    return 100 if norm1 == norm2  # Exacto

    # Fuzzy matching para variaciones ortográficas
    distance = levenshtein_distance(norm1, norm2)
    max_length = [norm1.length, norm2.length].max

    return 0 if max_length == 0

    match_percentage = ((max_length - distance) / max_length.to_f * 100).round
    [match_percentage, 0].max
  end

  # Extraer palabras clave del texto (4+ caracteres, sin stopwords)
  # Optimización: reduce el espacio de búsqueda en fuzzy matching
  def self.extract_keywords(text)
    return [] if text.blank?

    # Stopwords comunes en español e inglés
    stopwords = %w[el la los las de del a an and or the is are in on at to for with by from as of the a an and or but in on at to by for from with as is are have has had do does did would could should may might must can will shall]

    text.downcase
      .gsub(/[^a-záéíóúñ\s]/i, '')  # Solo letras, acentos y espacios
      .split(/\s+/)
      .select { |word| word.length >= 4 && !stopwords.include?(word) }
      .uniq
  end

  # Buscar vinculación con cartel en el catálogo (OPTIMIZADO)
  # Estrategia de dos fases:
  # FASE 1 (FAST PATH): Búsqueda exacta de palabras clave
  # FASE 2 (FALLBACK): Fuzzy matching selectivo solo si FASE 1 falla
  def self.identify_cartel_link(plain_text)
    cartels = get_cartel_catalog.where.not(name: "La Oficina")
    return nil if cartels.blank? || plain_text.blank?

    # Log detalles de búsqueda
    Rails.logger.info("[PASO 5 DEBUG] Cárteles después de exclusiones: #{cartels.count}")

    text_normalized = normalize_name(plain_text)
    keywords = extract_keywords(plain_text)
    Rails.logger.info("[PASO 5 DEBUG] Keywords extraídas: #{keywords.join(', ')}")
    matches = []

    # ============================================================
    # FASE 1: FAST PATH - Búsqueda exacta de palabras clave
    # (Muy rápido, alta confianza)
    # ============================================================
    cartels.each do |cartel|
      # Búsqueda exacta: nombre principal
      cartel_name_norm = normalize_name(cartel.name)
      if text_normalized.include?(cartel_name_norm)
        matches << {
          cartel: cartel,
          confidence: 100,
          match_type: :name_exact,
          field: :name,
          value: cartel.name,
          phase: :exact
        }
        next  # Ya encontramos match de alta confianza, saltar fuzzy
      end

      # Búsqueda de palabras clave en nombre
      if keywords.any? { |kw| cartel_name_norm.include?(kw) }
        matches << {
          cartel: cartel,
          confidence: 95,
          match_type: :name_keyword,
          field: :name,
          value: cartel.name,
          phase: :exact
        }
        next
      end

      # Búsqueda exacta: alias
      if cartel.alias.present?
        cartel.alias.each do |alias_name|
          next if alias_name.blank?
          alias_norm = normalize_name(alias_name)

          if text_normalized.include?(alias_norm)
            matches << {
              cartel: cartel,
              confidence: 95,
              match_type: :alias_exact,
              field: :alias,
              value: alias_name,
              phase: :exact
            }
            next
          end

          # Búsqueda de palabras clave en alias
          if keywords.any? { |kw| alias_norm.include?(kw) }
            matches << {
              cartel: cartel,
              confidence: 90,
              match_type: :alias_keyword,
              field: :alias,
              value: alias_name,
              phase: :exact
            }
            next
          end
        end
      end

      # Búsqueda exacta: legacy names
      if cartel.legacy_names.present?
        cartel.legacy_names.each do |legacy_name|
          next if legacy_name.blank?
          legacy_norm = normalize_name(legacy_name)

          if text_normalized.include?(legacy_norm)
            matches << {
              cartel: cartel,
              confidence: 90,
              match_type: :legacy_exact,
              field: :legacy_names,
              value: legacy_name,
              phase: :exact
            }
            next
          end

          # Búsqueda de palabras clave en legacy names
          if keywords.any? { |kw| legacy_norm.include?(kw) }
            matches << {
              cartel: cartel,
              confidence: 85,
              match_type: :legacy_keyword,
              field: :legacy_names,
              value: legacy_name,
              phase: :exact
            }
            next
          end
        end
      end
    end

    # Si FASE 1 encontró matches, retorna el mejor
    if matches.any? { |m| m[:phase] == :exact }
      best_match = matches.select { |m| m[:phase] == :exact }.max_by { |m| m[:confidence] }
      return best_match
    end

    # ============================================================
    # FASE 2: FALLBACK - Fuzzy matching SELECTIVO
    # (Solo si FASE 1 falla, más lento pero confiable)
    # ============================================================
    cartels.each do |cartel|
      # Fuzzy match SOLO con palabras clave del texto
      keywords.each do |keyword|
        # Nombre principal
        score = similarity_score(keyword, cartel.name)
        if score >= 85
          matches << {
            cartel: cartel,
            confidence: score,
            match_type: :name_fuzzy_keyword,
            field: :name,
            value: cartel.name,
            phase: :fuzzy
          }
        end

        # Alias
        if cartel.alias.present?
          cartel.alias.each do |alias_name|
            next if alias_name.blank?
            score = similarity_score(keyword, alias_name)
            if score >= 85
              matches << {
                cartel: cartel,
                confidence: score,
                match_type: :alias_fuzzy_keyword,
                field: :alias,
                value: alias_name,
                phase: :fuzzy
              }
            end
          end
        end

        # Legacy names
        if cartel.legacy_names.present?
          cartel.legacy_names.each do |legacy_name|
            next if legacy_name.blank?
            score = similarity_score(keyword, legacy_name)
            if score >= 80
              matches << {
                cartel: cartel,
                confidence: score,
                match_type: :legacy_fuzzy_keyword,
                field: :legacy_names,
                value: legacy_name,
                phase: :fuzzy
              }
            end
          end
        end
      end
    end

    return nil if matches.empty?

    # Log matches encontrados
    exact_matches = matches.select { |m| m[:phase] == :exact }
    fuzzy_matches = matches.select { |m| m[:phase] == :fuzzy }
    Rails.logger.info("[PASO 5 DEBUG] FASE 1 (Exacta): #{exact_matches.count} matches")
    Rails.logger.info("[PASO 5 DEBUG] FASE 2 (Fuzzy): #{fuzzy_matches.count} matches")

    # Retornar el match con mayor confianza
    best_match = matches.max_by { |m| m[:confidence] }
    Rails.logger.info("[PASO 5 DEBUG] MEJOR MATCH SELECCIONADO: #{best_match[:cartel].name} (confianza: #{best_match[:confidence]}%)")
    best_match
  end

  def self.execute!(hit)
    begin
      puts "\n🤖 PASO 5: Validando vinculación con cartel en catálogo..."

      OfacPipeline.start_timer("PASO 5 (Total)")
      OfacPipeline.start_timer("Step5: Búsqueda (Phase 1 + Phase 2)")
      cartel_match = identify_cartel_link(hit.plain_text)
      OfacPipeline.end_timer("Step5: Búsqueda (Phase 1 + Phase 2)")

      if cartel_match && cartel_match[:confidence] >= 80
        puts "   ✅ Vinculación encontrada: #{cartel_match[:cartel].name}"
        puts "      Confianza: #{cartel_match[:confidence]}%"
        puts "      Campo: #{cartel_match[:field]}"
        puts "      Valor coincidente: '#{cartel_match[:value]}'"
        puts "      Tipo match: #{cartel_match[:match_type]}"

        OfacPipeline.end_timer("PASO 5 (Total)")
        return {
          found: true,
          organization: cartel_match[:cartel],
          organization_id: cartel_match[:cartel].id,
          confidence: cartel_match[:confidence],
          match_type: cartel_match[:match_type],
          field: cartel_match[:field],
          value: cartel_match[:value]
        }
      else
        puts "   ❌ Sin vinculación detectada con cártel del catálogo"
        OfacPipeline.end_timer("PASO 5 (Total)")
        return {
          found: false,
          organization: nil,
          confidence: 0
        }
      end

    rescue => e
      puts "   ❌ Error en PASO 5: #{e.class} #{e.message}"
      nil
    end
  end
end

# ============================================================
# PASO 7: Extraer Alias del Candidato (Claude)
# ============================================================

class OfacPipeline::Step7
  def self.execute!(candidate, hit)
    begin
      puts "\n🤖 PASO 7: Extrayendo alias del candidato..."
      puts "=" * 60
      puts "Candidato: #{candidate[:fullname]}"

      firstname = candidate[:firstname]
      lastname1 = candidate[:lastname1]
      lastname2 = candidate[:lastname2].to_s.strip
      fullname = candidate[:fullname]

      plain_text = hit.plain_text.to_s

      if plain_text.blank? || plain_text.length < 100
        puts "   ⚠️  plain_text insuficiente para extracción de alias"
        return { success: true, alias: [] }
      end

      # Extraer alias con validación robusta
      extracted_aliases = extract_aliases_with_validation(
        firstname: firstname,
        lastname1: lastname1,
        lastname2: lastname2,
        fullname: fullname,
        plain_text: plain_text
      )

      puts "   ✅ Alias extraídos: #{extracted_aliases.inspect}"

      return {
        success: true,
        alias: extracted_aliases,
        source: "claude"
      }

    rescue => e
      puts "\n   ⚠️  Error en PASO 7 (alias extraction): #{e.class} #{e.message}"
      # Fallback: retornar array vacío
      return { success: true, alias: [] }
    end
  end

  private

  def self.extract_aliases_with_validation(firstname:, lastname1:, lastname2:, fullname:, plain_text:)
    api_key = OfacPipeline::Step2.get_anthropic_api_key

    unless api_key
      puts "   ⚠️  ANTHROPIC_API_KEY no encontrada en ENV/credentials/archivo, retornando alias vacío"
      return []
    end

    # Limpiar y preparar el texto (primeros 5000 caracteres para eficiencia)
    clean_text = clean_html_from_text(plain_text)[0, 5000]

    # Crear prompt con instrucciones muy específicas
    prompt = build_alias_extraction_prompt(
      firstname: firstname,
      lastname1: lastname1,
      lastname2: lastname2,
      fullname: fullname,
      text: clean_text
    )

    begin
      uri = URI("https://api.anthropic.com/v1/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri)
      req["x-api-key"] = api_key
      req["anthropic-version"] = "2023-06-01"
      req["content-type"] = "application/json"
      req.body = {
        model: "claude-sonnet-4-6",
        max_tokens: 500,
        messages: [{ role: "user", content: prompt }]
      }.to_json

      res = http.request(req)
      res_body = JSON.parse(res.body)

      if res.code.to_i != 200
        puts "   ⚠️  Claude error (#{res.code}): #{res_body.dig("error", "message")}"
        return []
      end

      content = res_body["content"]
      text_block = content.is_a?(Array) ? content.find { |c| c["type"] == "text" } : nil
      response_text = text_block&.dig("text").to_s.strip

      return [] if response_text.blank?

      # Extraer JSON del response
      json_match = response_text.match(/\{.*\}/m)
      return [] unless json_match

      parsed = JSON.parse(json_match[0])

      # Retornar array de alias (puede estar vacío)
      aliases_array = parsed["aliases"]
      return [] unless aliases_array.is_a?(Array)

      # Normalizar: remover nil, blancos, duplicados
      aliases_array
        .map { |a| a.to_s.strip }
        .reject(&:blank?)
        .uniq

    rescue JSON::ParserError => e
      puts "   ⚠️  JSON parse error: #{e.message}"
      return []
    rescue => e
      puts "   ⚠️  Claude API error: #{e.class} #{e.message}"
      return []
    end
  end

  def self.build_alias_extraction_prompt(firstname:, lastname1:, lastname2:, fullname:, text:)
    lastname2_mention = lastname2.present? ? "#{lastname1} #{lastname2}" : lastname1

    <<~PROMPT
      Tarea: Extraer SOLO los alias de una persona específica.

      PERSONA OBJETIVO:
      - Nombre: #{firstname}
      - Apellidos: #{lastname1} #{lastname2_mention}
      - Nombre Completo: #{fullname}

      INSTRUCCIONES CRÍTICAS:
      1. Busca ÚNICAMENTE alias de la persona mencionada arriba (#{fullname})
      2. NO incluyas alias de otras personas mencionadas en el texto
      3. Un alias es un nombre alternativo, apodo, o sobrenombre usado para referirse a esta MISMA persona
      4. Valida que cada alias corresponde realmente a #{firstname} #{lastname1}
      5. Si hay ambigüedad (podría referirse a otra persona), NO lo incluyas
      6. Retorna SOLO alias que aparecen en el texto adjunto
      7. Si no hay alias claros, retorna array vacío

      TEXTO A ANALIZAR:
      ---
      #{text}
      ---

      RESPONDE EN JSON (sin texto adicional):
      {
        "aliases": ["alias1", "alias2"],
        "confidence": número entre 0-100,
        "notas": "breve explicación de validación"
      }

      Si no encuentras alias, retorna: {"aliases": [], "confidence": 100, "notas": "sin alias encontrados"}
    PROMPT
  end

  def self.clean_html_from_text(text)
    clean = text.gsub(/<[^>]*>/m, '')
    clean = clean.gsub(/\s+/, ' ')
    clean = clean.gsub(/^(Menu|Mostrar|Estados|Secciones|Suplementos|Abrir en|Opens in|Share|Compartir).*?(?=\n|\s{2,})/i, '')
    clean.strip
  end
end

# ============================================================
# PASO 8: Determinar Rol OFAC
# ============================================================

class OfacPipeline::Step8
  OFAC_ROLES_FOR_PIPELINE = {
    autoridad_cooptada: {
      role_name: "Autoridad cooptada",
      description: "Trabajadores del sector público vinculados con la organización",
      indicators: [
        "gobierno", "funcionario", "policía", "militar", "alcalde",
        "diputado", "magistrado", "senador", "gobernador", "delegado",
        "secretario de seguridad", "comisario", "coronel", "general",
        "presidente municipal", "juez", "fiscal"
      ]
    },

    lider: {
      role_name: "Líder",
      description: "Primer nivel en la estructura criminal",
      indicators: [
        "líder", "patrón", "jefe máximo", "fundador", "dirigente",
        "cabeza de la organización", "máxima autoridad", "supremo",
        "caudillo", "capo", "cabeceante", "jefe de la organización"
      ]
    },

    operador: {
      role_name: "Operador",
      description: "Segundo nivel u operativo (sicarios, extorsionadores, etc.)",
      indicators: [
        "sicario", "extorsionador", "operador", "soldado", "miembro activo",
        "distribuidor", "traficante local", "ejecutor", "pistolero",
        "sicaria", "narcopunto", "gatillero", "halcón"
      ]
    },

    socio: {
      role_name: "Socio",
      description: "Sector privado (empresarios, lavadores, abogados, etc.)",
      indicators: [
        "empresario", "abogado", "contador", "lavador de dinero",
        "proveedor", "contratista", "asesor", "testaferro", "consultor",
        "estructurador", "financiero", "notario", "gestor", "asesor legal"
      ]
    }
  }.freeze

  def self.execute!(candidate, hit, organization)
    begin
      puts "\n🤖 PASO 8: Determinando rol OFAC..."
      puts "=" * 60
      puts "Candidato: #{candidate[:fullname]}"
      puts "Organización: #{organization&.name || 'Desconocida'}"

      plain_text = hit.plain_text.to_s

      if plain_text.blank?
        puts "   ⚠️  plain_text insuficiente"
        return { success: true, role_name: "Sin definir", role_id: get_role_id("Sin definir"), confidence: 0 }
      end

      # Extraer rol con validación robusta
      result = extract_role_with_claude(
        firstname: candidate[:firstname],
        lastname1: candidate[:lastname1],
        lastname2: candidate[:lastname2],
        fullname: candidate[:fullname],
        organization_name: organization&.name,
        plain_text: plain_text
      )

      if result.nil?
        puts "   ⚠️  No se pudo determinar rol, usando fallback"
        return { success: true, role_name: "Sin definir", role_id: get_role_id("Sin definir"), confidence: 0 }
      end

      role_id = get_role_id(result[:role_name])
      puts "   ✅ Rol determinado: #{result[:role_name]} (Confianza: #{result[:confidence]}%)"

      return {
        success: true,
        role_name: result[:role_name],
        role_id: role_id,
        confidence: result[:confidence]
      }

    rescue => e
      puts "   ⚠️  Error en PASO 8: #{e.class} #{e.message}"
      return { success: true, role_name: "Sin definir", role_id: get_role_id("Sin definir"), confidence: 0 }
    end
  end

  private

  def self.extract_role_with_claude(firstname:, lastname1:, lastname2:, fullname:, organization_name:, plain_text:)
    api_key = OfacPipeline::Step2.get_anthropic_api_key

    unless api_key
      return nil
    end

    clean_text = clean_html_from_text(plain_text)[0, 4000]

    prompt = build_role_extraction_prompt(
      firstname: firstname,
      lastname1: lastname1,
      lastname2: lastname2,
      fullname: fullname,
      organization_name: organization_name,
      text: clean_text
    )

    begin
      uri = URI("https://api.anthropic.com/v1/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri)
      req["x-api-key"] = api_key
      req["anthropic-version"] = "2023-06-01"
      req["content-type"] = "application/json"
      req.body = {
        model: "claude-sonnet-4-6",
        max_tokens: 300,
        messages: [{ role: "user", content: prompt }]
      }.to_json

      res = http.request(req)
      res_body = JSON.parse(res.body)

      if res.code.to_i != 200
        return nil
      end

      content = res_body["content"]
      text_block = content.is_a?(Array) ? content.find { |c| c["type"] == "text" } : nil
      response_text = text_block&.dig("text").to_s.strip

      return nil if response_text.blank?

      json_match = response_text.match(/\{.*\}/m)
      return nil unless json_match

      parsed = JSON.parse(json_match[0])

      role_name = parsed["role"]
      confidence = parsed["confidence"].to_i

      # Validar que sea uno de los 4 roles OFAC
      valid_roles = OFAC_ROLES_FOR_PIPELINE.values.map { |r| r[:role_name] }
      return nil unless valid_roles.include?(role_name)

      {
        role_name: role_name,
        confidence: confidence
      }

    rescue => e
      return nil
    end
  end

  def self.build_role_extraction_prompt(firstname:, lastname1:, lastname2:, fullname:, organization_name:, text:)
    <<~PROMPT
      TAREA: Clasificar el rol de una persona en UNA de 4 categorías OFAC.

      PERSONA OBJETIVO: #{fullname}
      ORGANIZACIÓN: #{organization_name}

      CATEGORÍAS VÁLIDAS:

      1. "Autoridad cooptada"
         - Descripción: Trabajadores del sector público vinculados
         - Indicadores: gobierno, funcionario, policía, militar, alcalde, diputado, etc.

      2. "Líder"
         - Descripción: Primer nivel en la estructura criminal
         - Indicadores: líder, patrón, jefe máximo, capo, caudillo, etc.

      3. "Operador"
         - Descripción: Segundo nivel u operativo
         - Indicadores: sicario, extorsionador, operador, soldado, distribuidor, etc.

      4. "Socio"
         - Descripción: Sector privado (empresarios, lavadores, abogados, etc.)
         - Indicadores: empresario, abogado, lavador de dinero, proveedor, consultor, etc.

      TEXTO A ANALIZAR:
      ---
      #{text}
      ---

      INSTRUCCIONES:
      - Clasifica SOLO a #{fullname} (no otras personas mencionadas)
      - Busca indicadores específicos del rol en el texto
      - Si hay ambigüedad, es probablemente "Operador" (nivel operativo)
      - Retorna JSON

      RESPONDE SOLO EN JSON (sin texto adicional):
      {
        "role": "uno de los 4 roles",
        "confidence": número entre 0-100,
        "evidence": "fragmento que apoya esta clasificación"
      }
    PROMPT
  end

  def self.get_role_id(role_name)
    Role.find_by(name: role_name)&.id || nil
  end

  def self.clean_html_from_text(text)
    clean = text.gsub(/<[^>]*>/m, '')
    clean = clean.gsub(/\s+/, ' ')
    clean = clean.gsub(/^(Menu|Mostrar|Estados|Secciones|Suplementos|Abrir en|Opens in|Share|Compartir).*?(?=\n|\s{2,})/i, '')
    clean.strip
  end
end

# ============================================================
# PASO 8.5: Estimar Género
# ============================================================

class OfacPipeline::StepGender
  def self.execute!(candidate, hit)
    firstname = candidate[:firstname].to_s.strip

    # 1. Buscar en CSV de nombres con género conocido
    gender_from_csv = search_gender_in_csv(firstname)
    return { success: true, gender: gender_from_csv, source: "csv", confidence: 100 } if gender_from_csv

    # 2. Si no está en CSV, usar Claude para estimar
    gender_from_claude = estimate_gender_with_claude(firstname)
    if gender_from_claude
      return { success: true, gender: gender_from_claude, source: "claude", confidence: 85 }
    end

    # 3. Si todo falla, retornar desconocido
    { success: true, gender: "DESCONOCIDO", source: "fallback", confidence: 0 }
  end

  private

  def self.search_gender_in_csv(firstname)
    csv_path = File.expand_path("../scripts/names_by_gender.csv", __dir__)
    return nil unless File.exist?(csv_path)

    firstname_normalized = firstname.downcase.strip

    CSV.foreach(csv_path, headers: true) do |row|
      csv_name = row['firstname']&.downcase&.strip
      next unless csv_name == firstname_normalized

      gender_raw = row['genero_estimado']&.strip&.downcase
      case gender_raw
      when 'masculino'
        return 'MASCULINO'
      when 'femenino'
        return 'FEMENINO'
      when 'desconocido'
        return 'DESCONOCIDO'
      end
    end

    nil
  end

  def self.estimate_gender_with_claude(firstname)
    api_key = OfacPipeline.load_anthropic_api_key
    return nil if api_key.blank?

    prompt = %{
      Dado el nombre: "#{firstname}"

      Estima el género probable de una persona con este nombre en contexto hispanohablante.

      Responde SOLO con una de estas palabras, sin explicación:
      - MASCULINO
      - FEMENINO
      - DESCONOCIDO

      Si no estás seguro, responde: DESCONOCIDO
    }

    uri = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = api_key
    request['anthropic-version'] = '2023-06-01'

    body = {
      model: 'claude-opus-5-5',
      max_tokens: 10,
      messages: [
        { role: 'user', content: prompt }
      ]
    }

    request.body = body.to_json

    begin
      response = http.request(request)
      result = JSON.parse(response.body)

      if response.code == '200' && result['content']&.first
        gender_text = result['content'].first['text'].strip.upcase
        case gender_text
        when 'MASCULINO', 'FEMENINO', 'DESCONOCIDO'
          return gender_text
        end
      end
    rescue => e
      puts "⚠️  Error consultando Claude para género: #{e.message}"
    end

    nil
  end
end

# ============================================================
# PASO 9: Presentar Confirmación (Opción A)
# ============================================================

class OfacPipeline::Step9
  def self.present_for_confirmation(candidate, hit, organization, alias_array, role_name, role_id)
    puts "\n" + "=" * 100
    puts "PASO 9: CONFIRMACIÓN DE DATOS"
    puts "=" * 100

    # Tabla 1: HIT
    puts "\n📰 TABLA 1: HIT VALIDADO"
    puts "-" * 100
    print_hit_table(hit)

    # Tabla 2: MEMBER
    puts "\n👤 TABLA 2: MEMBER A CREAR"
    puts "-" * 100
    print_member_table(candidate, hit, organization, alias_array, role_name)

    puts "\n" + "=" * 100
  end

  private

  def self.print_hit_table(hit)
    puts format_row("Legacy ID", hit.legacy_id)
    puts format_row("Fuente (Link)", hit.link)
    puts format_row("Fecha del evento", hit.date)
    location = if hit.town.present?
                 "#{hit.town.county&.name}, #{hit.town.county&.state&.name}"
               else
                 "—"
               end
    puts format_row("Ubicación", location)
    puts format_row("Plain text válido", "✅ #{hit.plain_text.length} caracteres")
    puts "\nFragmento inicial:"
    puts "  #{hit.plain_text[0, 350]}..."
  end

  def self.print_member_table(candidate, hit, organization, alias_array, role_name)
    puts format_row("Nombre Completo", "#{candidate[:firstname]} #{candidate[:lastname1]} #{candidate[:lastname2]}")
    puts format_row("  - Firstname", candidate[:firstname])
    puts format_row("  - Lastname1", candidate[:lastname1])
    puts format_row("  - Lastname2", candidate[:lastname2])

    if alias_array.any?
      aliases_str = alias_array.map { |a| "• #{a}" }.join(", ")
      puts format_row("Alias extraídos", aliases_str)
    else
      puts format_row("Alias extraídos", "(sin alias)")
    end

    puts format_row("Rol propuesto", role_name)
    puts format_row("  Descripción", "(#{get_role_description(role_name)})")
    puts format_row("Organización", organization&.name || "—")
  end

  def self.format_row(label, value)
    sprintf("  %-30s │ %s", label, value)
  end

  def self.get_role_description(role_name)
    case role_name
    when "Autoridad cooptada"
      "Trabajadores del sector público vinculados"
    when "Líder"
      "Primer nivel en la estructura criminal"
    when "Operador"
      "Segundo nivel u operativo"
    when "Socio"
      "Sector privado (empresarios, lavadores, etc.)"
    else
      "Rol no definido"
    end
  end
end

# ============================================================
# EJECUCIÓN
# ============================================================

if __FILE__ == $0
  puts "\n" + "=" * 60
  puts "🚀 OFAC Member Pipeline Executor"
  puts "=" * 60

  # PASO 1
  candidate = OfacPipeline::Step1.execute!

  if candidate.nil?
    puts "\n❌ PASO 1 falló o no hay candidatos disponibles"
    exit 1
  end

  # PASO 2
  paso2_result = OfacPipeline::Step2.execute!(candidate)

  if paso2_result.nil?
    puts "\n⚠️  PASO 2 no encontró Hit válido"
    exit 0
  end

  hit = paso2_result[:hit]
  was_existing_hit = paso2_result[:was_existing_hit]

  # PASO 3: Extraer fecha con Claude
  puts "\n🤖 PASO 3: Extrayendo fecha con Claude..."
  updated_date = OfacPipeline::Step2.extract_date_with_claude(hit.plain_text)

  if updated_date
    hit.update!(date: updated_date)
    hit.reload
    puts "✅ Fecha extraída: #{updated_date}"
  else
    fallback_date = Date.today
    hit.update!(date: fallback_date)
    puts "⚠️  Claude no pudo extraer fecha, usando fallback Date.today: #{fallback_date}"
  end

  # PASO 4: Extraer ubicación con Claude
  puts "\n🤖 PASO 4: Extrayendo ubicación con Claude..."
  updated_town_id = OfacPipeline::Step2.extract_location_with_claude(hit.plain_text, hit.town_id)

  if updated_town_id && updated_town_id != hit.town_id
    hit.update!(town_id: updated_town_id)
    hit.reload
    puts "✅ Ubicación actualizada"
  else
    puts "⚠️  Ubicación sin cambios o error"
  end

  # PASO 5: Validar vinculación con cartel
  puts "\n🤖 PASO 5: Validando vinculación con cartel..."
  cartel_match = OfacPipeline::Step5.execute!(hit)

  # Capturar organization_id para próximos pasos
  organization_id = nil
  if cartel_match && cartel_match[:found]
    organization_id = cartel_match[:organization_id]
    puts "✅ Cartel identificado: #{cartel_match[:organization].name} (Confianza: #{cartel_match[:confidence]}%)"
    puts "   Organization ID (temporal): #{organization_id}"
  else
    puts "⚠️  No se identificó cartel en el catálogo"
  end

  # PASO 6: Validación final con reintentos
  paso6_result = OfacPipeline::Step6.validate_and_retry(
    candidate,
    hit,
    organization_id,
    was_existing_hit: was_existing_hit,
    attempt: 1
  )

  if paso6_result[:success]
    puts "\n" + "=" * 80
    puts "✅ PASO 6 VALIDACIÓN EXITOSA"
    puts "=" * 80

    # PASO 7: Extraer alias
    paso7_result = OfacPipeline::Step7.execute!(
      paso6_result[:candidate],
      paso6_result[:hit]
    )

    # PASO 8: Determinar rol
    organization = Organization.find_by(id: paso6_result[:organization_id])
    paso8_result = OfacPipeline::Step8.execute!(
      paso6_result[:candidate],
      paso6_result[:hit],
      organization
    )

    # PASO 9: Presentar confirmación
    OfacPipeline::Step9.present_for_confirmation(
      paso6_result[:candidate],
      paso6_result[:hit],
      organization,
      paso7_result[:alias],
      paso8_result[:role_name],
      paso8_result[:role_id]
    )

    puts "\n" + "=" * 80
    puts "✅ PIPELINE COMPLETO (PASOS 1-9)"
    puts "=" * 80
    puts "\n📦 RESUMEN FINAL DE DATOS PARA CREAR MEMBER:"
    puts "   ✓ Firstname: #{paso6_result[:candidate][:firstname]}"
    puts "   ✓ Lastname1: #{paso6_result[:candidate][:lastname1]}"
    puts "   ✓ Lastname2: #{paso6_result[:candidate][:lastname2]}"
    puts "   ✓ Alias: #{paso7_result[:alias].inspect}"
    puts "   ✓ Role: #{paso8_result[:role_name]}"
    puts "   ✓ Organization: #{organization&.name}"
    puts "   ✓ Hit ID: #{paso6_result[:hit].id}"
    puts "=" * 80
  else
    puts "\n" + "=" * 80
    puts "❌ PROCESO FALLIDO"
    puts "=" * 80
    puts "Candidato: #{paso6_result[:candidate_name]}"
    puts "Causa principal: #{paso6_result[:primary_cause]}"
    if paso6_result[:all_causes]
      puts "Todas las causas:"
      paso6_result[:all_causes].each { |c| puts "  • #{c}" }
    end
    puts "=" * 80
  end

  exit 0
end
