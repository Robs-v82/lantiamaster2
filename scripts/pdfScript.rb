require 'wicked_pdf'

myHits = Hit.left_outer_joins(:pdf_attachment).where(active_storage_attachments: { id: nil }).limit(10)
myHits = myHits.where.not(link: nil)

pdf_generator = WickedPdf.new

myHits.each do |hit|
  next unless hit.link.present? && hit.link.start_with?('http')

  begin
    puts "🌀 Generando PDF para: #{hit.link}"

    # Renderiza el PDF desde la URL
    pdf = pdf_generator.pdf_from_url(hit.link)

    # Adjunta el PDF al modelo
    filename = "hit_#{hit.id}.pdf"
    io = StringIO.new(pdf)
    hit.pdf.attach(io: io, filename: filename, content_type: 'application/pdf')

    puts "✅ PDF adjuntado a Hit ##{hit.id}"
  rescue => e
    puts "⚠️ Error en Hit ##{hit.id}: #{e.message}"
  end
end
