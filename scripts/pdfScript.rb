require 'grover'

Grover.configure do |config|
  config.options = {
    executable_path: '/usr/bin/chromium', # o '/usr/bin/chromium-browser'
    format: 'A4'
  }
end

myHits = Hit.left_outer_joins(:pdf_attachment).where(active_storage_attachments: { id: nil }).limit(10)
myHits = myHits.where.not(:link=>nil)
myHits.each do |hit|
  next unless hit.link.present? && hit.link.start_with?('http')

  begin
    puts "🌀 Generando PDF para: #{hit.link}"

    pdf = Grover.new(hit.link).to_pdf

    filename = "hit_#{hit.id}.pdf"
    io = StringIO.new(pdf)
    hit.pdf.attach(io: io, filename: filename, content_type: 'application/pdf')

    puts "✅ PDF adjuntado a Hit ##{hit.id}"
  rescue => e
    puts "⚠️ Error en Hit ##{hit.id}: #{e.message}"
  end
end