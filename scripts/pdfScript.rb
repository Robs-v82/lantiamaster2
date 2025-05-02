require 'wicked_pdf'
require 'open-uri'

# Define el user agent que usarás en la descarga
user_agent = "WickedPdf/1.0 (Lantia Intelligence)"

myHits = Hit.left_outer_joins(:pdf_attachment).where(active_storage_attachments: { id: nil }).limit(10)
myHits = myHits.where.not(:link => nil)

myHits.each do |hit|
  next unless hit.link.present? && hit.link.start_with?('http')

  begin
    puts "🌀 Generando PDF para: #{hit.link}"

    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")

    image_url = ActionController::Base.helpers.asset_url('Lantia_LogoPositivo.png', type: :image)

    html_header = <<~HTML
      <div style='font-size: 14px; font-family: sans-serif; border-bottom: 1px solid #ccc; padding-bottom: 10px; margin-bottom: 20px;'>
        <img src='#{image_url}' style='width: 100px; display: block; margin-bottom: 10px;' alt='Lantia Logo'>
        <div style="display: block; font-size: 14px !important">
          Fuente:<span style="font-weight: 800; padding-bottom: 5px">#{hit.link}</span><br>
          Capturado:<span style="font-weight: 800; padding-bottom: 5px">#{timestamp}</span><br>
          User-Agent:<span style="font-weight: 800; padding-bottom: 5px">#{user_agent}</span><br>
          Organización:<span style="font-weight: 800; padding-bottom: 5px">Decisiones, Estrategias y Mejores Prácticas</span>
        </div>
      </div>
    HTML

    # Descargar el contenido HTML de la página
    html_body = URI.open(hit.link, "User-Agent" => user_agent).read

    # Generar el PDF incluyendo encabezado con metadatos
    pdf = WickedPdf.new.pdf_from_string(
      html_header + html_body,
      margin: { top: 20, bottom: 10 },
      encoding: 'UTF-8'
    )

    filename = "hit_#{hit.id}.pdf"
    io = StringIO.new(pdf)
    hit.pdf.attach(io: io, filename: filename, content_type: 'application/pdf')

    puts "✅ PDF adjuntado a Hit ##{hit.id}"
  rescue => e
    puts "⚠️ Error en Hit ##{hit.id}: #{e.message}"
  end
end





