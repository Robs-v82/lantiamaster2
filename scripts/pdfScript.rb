require 'grover'

Hit.left_outer_joins(:pdf_attachment).where(active_storage_attachments: { id: nil }).each do |hit|
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