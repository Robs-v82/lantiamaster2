class ReportSummarizerService
  attr_reader :summary, :error

  def initialize(pdf_blob)
    @pdf_blob = pdf_blob
    @summary = nil
    @error = nil
  end

  def call
    return self if @pdf_blob.blank?

    begin
      pdf_content = @pdf_blob.download
      pdf_base64 = Base64.strict_encode64(pdf_content)

      client = Anthropic::Client.new(api_key: anthropic_api_key)

      response = client.messages(
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
                text: "Por favor, lee el reporte adjunto y genera un resumen ejecutivo."
              }
            ]
          }
        ]
      )

      @summary = extract_summary(response)
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
    "encabezados ni numeración, solo guiones. El tono es analítico y preciso."
  end

  def extract_summary(response)
    response.dig("content", 0, "text") || ""
  end

  def anthropic_api_key
    key_file = Rails.root.join("..", "..", "shared", "config", "anthropic_api_key").expand_path
    ENV["ANTHROPIC_API_KEY"].presence ||
      Rails.application.credentials.dig(:anthropic, :api_key) ||
      (File.read(key_file).strip if File.exist?(key_file))
  end
end
