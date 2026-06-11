class ReportSummarizerService
  attr_reader :summary, :error

  def initialize(pdf_content)
    @pdf_content = pdf_content
    @summary = nil
    @error = nil
  end

  def call
    return self if @pdf_content.blank?

    begin
      pdf_base64 = Base64.strict_encode64(@pdf_content)

      api_key = anthropic_api_key
      if api_key.blank?
        @error = "ANTHROPIC_API_KEY no configurada."
        Rails.logger.error("[ReportSummarizerService] #{@error}")
        return self
      end

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
        model: "claude-opus-4-5",
        max_tokens: 1024,
        system: system_prompt,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "document",
                source: {
                  type: "base64",
                  media_type: "application/pdf",
                  data: pdf_base64
                }
              },
              {
                type: "text",
                text: "Por favor, lee el reporte adjunto y genera un resumen ejecutivo. IMPORTANTE: El total de todas las palabras del resumen no debe exceder 180 palabras. Cuenta las palabras cuidadosamente y ajusta los bullets para cumplir estrictamente este límite."
              }
            ]
          }
        ]
      }.to_json

      res = http.request(req)
      body = JSON.parse(res.body)
      @summary = extract_summary(body)
      self
    rescue => e
      @error = "Error al generar resumen: #{e.class} - #{e.message}"
      Rails.logger.error("[ReportSummarizerService] #{@error}")
      self
    end
  end

  def ok?
    error.blank?
  end

  private

  def system_prompt
    "Eres un asistente editorial de Lantia Intelligence, firma mexicana de " \
    "inteligencia en seguridad. Tu tarea es leer el reporte adjunto y generar " \
    "un resumen ejecutivo en español para enviar por correo a suscriptores. " \
    "El resumen debe ser una lista de 5 a 8 bullets concisos. Cada bullet " \
    "describe un tema central del reporte en una oración directa, sin " \
    "encabezados ni numeración, solo guiones. El tono es analítico y preciso. " \
    "CRÍTICO: El total del resumen NO DEBE EXCEDER 180 PALABRAS. Ajusta la extensión " \
    "de los bullets para cumplir estrictamente este límite. Prioriza calidad sobre cantidad. " \
    "IMPORTANTE: Entre cada bullet debe haber EXACTAMENTE UNA LÍNEA EN BLANCO (un solo salto de línea). " \
    "No agrues espacios adicionales entre los bullets. Cada bullet inicia con un guión seguido de espacio."
  end

  def extract_summary(response)
    summary = response.dig("content", 0, "text") || ""
    # Normalizar espaciado: reducir múltiples saltos de línea a máximo uno (una línea en blanco)
    normalized = summary.gsub(/\n(\s*\n){2,}/, "\n\n").strip
    Rails.logger.info("[ReportSummarizerService] Resumen normalizado de Claude (primeros 500 chars): #{normalized[0..500].inspect}")
    normalized
  end

  def anthropic_api_key
    key_file = Rails.root.join("..", "..", "shared", "config", "anthropic_api_key").expand_path
    ENV["ANTHROPIC_API_KEY"].presence ||
      Rails.application.credentials.dig(:anthropic, :api_key) ||
      (File.read(key_file).strip if File.exist?(key_file))
  end
end
