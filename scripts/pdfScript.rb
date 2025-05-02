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

    # Timeout: 30 segundos para evitar cuelgues
    Timeout.timeout(30) do
      html_body = URI.open(hit.link, "User-Agent" => user_agent).read

      pdf = WickedPdf.new.pdf_from_string(
        html_header + html_body,
        disable_javascript: true,
        encoding: 'UTF-8',
        margin: { top: 20, bottom: 10 },
        javascript_delay: 3000, # da tiempo a que JS básico cargue
        disable_smart_shrinking: true,
        no_stop_slow_scripts: true,
        print_media_type: true,
        dpi: 96
      )

      io = StringIO.new(pdf)
      hit.pdf.attach(io: io, filename: "hit_#{hit.id}.pdf", content_type: 'application/pdf')
      puts "✅ PDF adjuntado a Hit ##{hit.id}"
    end

  rescue => e
    puts "⚠️ Error en Hit ##{hit.id}: #{e.message}"
    hit.update(protected_link: true) # marca como no procesable
  end

  sleep 5
  puts "📊 Estado del sistema:"
  puts `free -h`        # Muestra el uso de memoria RAM en formato legible
  puts `df -h /`        # Muestra el uso de disco en la raíz (/) principal
end





