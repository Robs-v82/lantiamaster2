ENV['RAILS_ENV'] ||= 'production'
require_relative '../config/environment'
require 'ferrum'

# Paso 1: Obtener primeros 50 miembros target sin título
name_frequencies = Name.all.pluck(:word, :freq).map { |w, f| [I18n.transliterate(w).downcase.strip, f] }.to_h

def normalize_name(str)
  I18n.transliterate(str.to_s).downcase.strip
end

candidates = Member.joins(:hits).distinct.select do |member|
  first = normalize_name(member.firstname)
  last1 = normalize_name(member.lastname1)
  last2 = normalize_name(member.lastname2)

  valid = [first, last1, last2].all? { |n| n.match?(/\A[a-zñü\s]{2,}\z/) }
  next false unless valid

  f1 = name_frequencies[first] || 5
  f2 = name_frequencies[last1] || 5
  f3 = name_frequencies[last2] || 5

  ((f1 * f2 * f3) / 10000.0).round < 2
end

target_members = candidates.reject { |m| m.titles.exists? }
puts "🔍 Procesando #{target_members.size} miembros sin títulos..."

# Paso 2: Cargar año activo

# Paso 3: Inicializar navegador
browser = Ferrum::Browser.new(
  headless: true,
  timeout: 30,
  process_timeout: 30,
  window_size: [1200, 900],
  browser_options: {
    'no-sandbox': nil,
    'disable-gpu': nil,
    'disable-dev-shm-usage': nil,
    'disable-software-rasterizer': nil,
    'disable-devtools': nil,
    'mute-audio': nil
  }
)

target_members[-100..-1].each_with_index do |member, idx|
  puts "\n👤 [#{idx + 1}/#{target_members.size}] Buscando cédula de #{member.fullname}"

  browser.goto("https://www.cedulaprofesional.sep.gob.mx/cedula/presidencia/indexAvanzada.action")
  sleep 1

  # Completar formulario
  browser.at_css("input#nombre")&.focus&.type(member.firstname)
  browser.at_css("input#paterno")&.focus&.type(member.lastname1)
  browser.at_css("input#materno")&.focus&.type(member.lastname2)

  # Enviar formulario
  boton = browser.at_xpath("//span[contains(text(),'Consultar')]/ancestor::span[contains(@class, 'dijitButtonNode')]")
  boton&.click
  sleep 5

  filas = browser.css(".dojoxGridRow")
  next if filas.empty?

  def normalize_text(text)
    I18n.transliterate(text.to_s).strip.upcase
  end

  coincidencia = filas.find do |fila|
    celdas = fila.css(".dojoxGridCell").map(&:text).map(&:strip)
    nombre, ape1, ape2 = celdas[1], celdas[2], celdas[3]

    normalize_text(nombre) == normalize_text(member.firstname) &&
      normalize_text(ape1) == normalize_text(member.lastname1) &&
      normalize_text(ape2) == normalize_text(member.lastname2)
  end

  unless coincidencia
    puts "❌ No se encontró coincidencia exacta para #{member.fullname}"
    next
  end

  # Clic sobre la fila
  first_cell = coincidencia.css("td").first
  first_cell&.focus&.click
  sleep 3

  # Verificar detalle
  nombre_div = browser.at_css("#detalleNombre")
  unless nombre_div && !nombre_div.text.strip.empty?
    puts "⚠️ El detalle no se cargó correctamente para #{member.fullname}"
    next
  end

  # Extraer datos
  cedula     = browser.at_css("#detalleCedula")&.text&.strip
  nombre     = browser.at_css("#detalleNombre")&.text&.strip
  genero     = browser.at_css("#detalleGenero")&.text&.strip
  profesion  = browser.at_css("#detalleProfesion")&.text&.strip
  institucion= browser.at_css("#detalleInstitucion")&.text&.strip
  fecha      = browser.at_css("#detalleFecha")&.text&.strip
  tipo       = browser.at_css("#detalleTipo")&.text&.strip

  puts "📄 Detalle: #{cedula} | #{profesion} | #{institucion}"

  # Buscar o crear institución
  org_name = institucion.titleize
  organization = Organization.find_or_create_by(name: org_name)

  #Buscar o crear año
  year = Year.find_or_create_by(:name=> fecha)

  # Crear título
  Title.create!(
    legacy_id: cedula,
    type: tipo,
    profesion: profesion,
    member_id: member.id,
    organization_id: organization.id,
    year_id: year.id
  )

  puts "✅ Título creado para #{member.fullname}"
rescue => e
  puts "❌ Error procesando #{member.fullname}: #{e.message}"
end

browser.quit
puts "\n🎉 Proceso completado."
