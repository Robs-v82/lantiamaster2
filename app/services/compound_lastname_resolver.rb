require "net/http"
require "uri"
require "json"

class CompoundLastnameResolver
  def self.resolve(lastname_tokens, firstname)
    return nil if lastname_tokens.blank? || lastname_tokens.empty?
    return { lastname1: lastname_tokens[0], lastname2: lastname_tokens[1] } if lastname_tokens.size <= 2

    # Apellidos compuestos: aplicar estrategia de 4 niveles
    result = find_in_database(lastname_tokens, firstname) ||
             ask_claude(lastname_tokens, firstname) ||
             search_internet(lastname_tokens, firstname) ||
             fallback(lastname_tokens)

    result
  end

  private

  # ============================================================
  # NIVEL 1: Búsqueda en BD
  # ============================================================
  def self.find_in_database(lastname_tokens, firstname)
    normalized_tokens = lastname_tokens.map { |t| normalize_for_search(t) }
    full_normalized = normalized_tokens.join(" ")

    # Buscar Members con apellidos compuestos que coincidan
    Member.where.not(lastname1: [nil, ""], lastname2: [nil, ""]).find_each do |member|
      member_last1_normalized = normalize_for_search(member.lastname1)
      member_last2_normalized = normalize_for_search(member.lastname2)
      member_combined = "#{member_last1_normalized} #{member_last2_normalized}"

      if member_combined == full_normalized
        return {
          lastname1: member.lastname1,
          lastname2: member.lastname2,
          source: "database"
        }
      end
    end

    nil
  end

  # ============================================================
  # NIVEL 2: Claude API
  # ============================================================
  def self.ask_claude(lastname_tokens, firstname)
    combined = lastname_tokens.join(" ")
    api_key = ENV["ANTHROPIC_API_KEY"]

    unless api_key
      Rails.logger.warn("CompoundLastnameResolver: ANTHROPIC_API_KEY no configurada")
      return nil
    end

    prompt = "Soy un sistema de clasificación de nombres mexicanos. Necesito identificar cuál es el apellido paterno y cuál es el apellido materno.\n\nPersona: #{firstname} #{combined}\n\nEn México, la convención es: Nombre Apellido_Paterno Apellido_Materno\n\nResponde SOLO en JSON (sin texto adicional):\n{\"apellido_paterno\": \"...\", \"apellido_materno\": \"...\", \"confianza\": número entre 0 y 100}"

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
        Rails.logger.warn("CompoundLastnameResolver: Claude error (#{res.code}): #{res_body.dig("error", "message")}")
        return nil
      end

      content = res_body["content"]
      text_block = content.is_a?(Array) ? content.find { |c| c["type"] == "text" } : nil
      response_text = text_block&.dig("text").to_s.strip

      return nil if response_text.blank?

      # Extraer JSON del response (puede tener texto adicional)
      json_match = response_text.match(/\{.*\}/m)
      return nil unless json_match

      parsed = JSON.parse(json_match[0])

      if parsed["confianza"].to_i >= 75
        return {
          lastname1: normalize_and_capitalize(parsed["apellido_paterno"]),
          lastname2: normalize_and_capitalize(parsed["apellido_materno"]),
          source: "claude",
          confidence: parsed["confianza"]
        }
      end
    rescue => e
      Rails.logger.warn("CompoundLastnameResolver: Claude API error: #{e.class} #{e.message}")
    end

    nil
  end

  # ============================================================
  # NIVEL 3: WebSearch (validación de combinación común)
  # ============================================================
  def self.search_internet(lastname_tokens, firstname)
    combined = lastname_tokens.join(" ")
    search_query = "#{firstname} #{combined} Mexico"

    begin
      # Usar WebSearch si está disponible (via MCP o similar)
      # Por ahora, retornamos nil - se puede implementar WebSearch
      # cuando esté disponible en el ambiente
      nil
    rescue => e
      Rails.logger.warn("CompoundLastnameResolver: WebSearch error: #{e.message}")
      nil
    end
  end

  # ============================================================
  # NIVEL 4: Fallback
  # ============================================================
  def self.fallback(lastname_tokens)
    lastname1 = normalize_and_capitalize(lastname_tokens[0])
    lastname2 = normalize_and_capitalize(lastname_tokens[1..-1].join(" "))

    {
      lastname1: lastname1,
      lastname2: lastname2,
      source: "fallback"
    }
  end

  # ============================================================
  # Funciones de Normalización
  # ============================================================

  def self.normalize_for_search(text)
    I18n.transliterate(text.to_s.strip.downcase)
  end

  def self.normalize_and_capitalize(text)
    I18n.transliterate(text.to_s.strip).split.map(&:capitalize).join(" ")
  end
end
