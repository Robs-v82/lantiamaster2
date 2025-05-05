require 'wicked_pdf'
require 'open-uri'
require 'timeout'

user_agent = "WickedPdf/1.0 (Lantia Intelligence)"

myHits = Hit.left_outer_joins(:pdf_attachment)
            .where(active_storage_attachments: { id: nil })
            .where(protected_link: false)
            .where.not(link: nil)
            .limit(10)

myHits.each do |hit|
  next unless hit.link.present? && hit.link.start_with?('http')

  begin
    puts "🌀 Generando PDF para: #{hit.link}"
    timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    image_url = "https://dashboard.lantiaintelligence.com/assets/Lantia_LogoPositivo.png"

    html_header = <<~HTML
      <div style='font-size: 14px; font-family: sans-serif; border-bottom: 1px solid #ccc; padding-bottom: 10px; margin-bottom: 20px;'>
        <img src='#{image_url}' style='width: 160px; display: block; margin-bottom: 10px;' alt='Lantia Logo'>
        <div style="font-size: 14px;">
          Fuente:<span style="font-weight: 800;"> #{hit.link}</span><br>
          Capturado:<span style="font-weight: 800;"> #{timestamp}</span><br>
          User-Agent:<span style="font-weight: 800;"> #{user_agent}</span><br>
          Organización:<span style="font-weight: 800;"> Estrategias, Decisiones y Mejores Prácticas</span>
        </div>
      </div>
    HTML

    Timeout.timeout(45) do
      html_body = URI.open(hit.link, "User-Agent" => user_agent).read

      pdf = WickedPdf.new.pdf_from_string(
        html_header + html_body,
        encoding: 'UTF-8',
        margin: { top: 20, bottom: 10 },
        disable_javascript: true,
        javascript_delay: 3000,
        print_media_type: true,
        zoom: 1.25,
        dpi: 150,
        viewport_size: '1280x1024'
      )

      io = StringIO.new(pdf)
      hit.pdf.attach(io: io, filename: "hit_#{hit.id}.pdf", content_type: 'application/pdf')
      puts "✅ PDF adjuntado a Hit ##{hit.id}"
    end

  rescue => e
    puts "⚠️ Error en Hit ##{hit.id}: #{e.message}"
    hit.update(protected_link: true)
  end

  sleep 5
  puts "📊 Estado del sistema:"
  puts `free -h`        # uso de memoria
  puts `df -h /`        # espacio en disco
end






