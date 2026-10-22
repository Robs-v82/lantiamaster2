#!/usr/bin/env ruby
# Script para generar CSV de organizaciones criminales
# Uso: rails runner scripts/generate_organizations_csv.rb

require 'csv'

# Encabezados exactos del archivo original
HEADERS = [
  "NOMBRE",
  "ESTATUS",
  "NOMBRES ALTERNOS",
  "SIGLAS",
  "TIPO",
  "SUBTIPO",
  "LÍDER",
  "ORIGEN",
  "ALIANZAS",
  "CONFLICTOS",
  "Narcotráfico",
  "Narcomenudeo",
  "Extorsión (extorsión presencial cobro de derecho de piso y secuestro-levantones)",
  "Mercado Ilícito de Hidrocarburos (MIH)",
  "Trata y tráfico de personas",
  "Tráfico de armas (profesionales de la violencia – sicarios)",
  "Robo de ferrocarril",
  "Robo a transportista (camión articulado -robo a transporte público)",
  "Delitos contra fauna-flora silvestre (tala clandestina, pesca y minería ilegal, tráfico de especies animales y vegetales)",
  "Contrabando de mercancías (productos apócrifos, medicinas, bienes culturales)",
  "Lavado de dinero (participación en el mercado formal con empresas fachada o como profesionales de la violencia para empresarios)",
  "Fraude",
  "Actos de terrorismo (coches bomba, explosivos en establecimientos comerciales como sucursales bancarias, amenazas y homicidio de activistas y periodistas)",
  "Vandalismo (daño sistemático a infraestructura urbana)",
  "Robo a comercio (robo bancario-negocio)",
  "Robo a casa habitación",
  "Robo de vehículo (robo a transeúnte)",
  "Piratería (robo a embarcaciones o plataformas petroleras)",
  "Autogobierno penitenciario (control de la cárcel por medio de la extorsión)"
]

# Nombres de divisiones en el mismo orden (para búsqueda en BD)
ACTIVIDADES_BD = [
  "Narcotráfico",
  "Narcomenudeo",
  "Extorsión",
  "Mercado Ilícito de Hidrocarburos",
  "Trata y tráfico de personas",
  "Tráfico de armas",
  "Robo de ferrocarril",
  "Robo de transportistas",
  "Delitos contra fauna-flora silvestre",
  "Contrabando de mercancías",
  "Lavado de dinero",
  "Fraude",
  "Actos de terrorismo",
  "Vandalismo",
  "Robo a comercio",
  "Robo a casa habitación",
  "Robo de vehículo",
  "Piratería",
  "Autogobierno penitenciario"
]

# Helper para limpiar campos CSV
def clean_csv_field(value)
  return "" if value.blank?
  value.to_s.gsub(/[\r\n]+/, " ").strip
end

# Timestamp para el nombre del archivo
timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
desktop_path = File.expand_path("~/Desktop")
output_file = "#{desktop_path}/organizaciones_#{timestamp}.csv"

# Crear directorio si no existe
FileUtils.mkdir_p(desktop_path)

puts "=" * 80
puts "GENERANDO CSV DE ORGANIZACIONES"
puts "=" * 80
puts "\n📁 Archivo de salida: #{output_file}"
puts "📊 Total de encabezados: #{HEADERS.count}"
puts "🎯 Total de actividades: #{ACTIVIDADES_BD.count}\n"

# Obtener todas las organizaciones del Sector 98 (CARTELS)
# Activas e inactivas, deduplicadas
all_cartels = Sector.where(:scian2=>98).last.organizations.uniq
organizations = all_cartels.sort_by(&:name)
total_orgs = organizations.count

puts "🔄 Procesando #{total_orgs} organizaciones únicas...\n"

CSV.open(output_file, "w", encoding: "UTF-8") do |csv|
  # Escribir encabezados
  csv << HEADERS

  processed = 0
  organizations.each do |org|
    processed += 1

    # Mostrar progreso cada 100 organizaciones
    if processed % 100 == 0
      puts "   Procesadas: #{processed}/#{total_orgs}"
    end

    # 1. NOMBRE
    nombre = clean_csv_field(org.name)

    # 2. ESTATUS
    estatus = org.active ? "Activa" : "Inactiva"

    # 3. NOMBRES ALTERNOS
    nombres_alternos = clean_csv_field(org.alias&.join("; ") || "")

    # 4. SIGLAS
    siglas = clean_csv_field(org.acronym || "")

    # 5. TIPO
    tipo = clean_csv_field(org.mainleague&.name || "")

    # 6. SUBTIPO
    subtipo = clean_csv_field(org.thissubleague&.name || "")

    # 7. LÍDER (parent si existe, si no origin.first)
    lider = clean_csv_field(org.parent&.name || org.origin&.first || "")

    # 8. ORIGEN (convertir IDs a nombres si están guardados como strings)
    origen = if org.origin.any?
      origen_names = org.origin.map do |origin_item|
        if origin_item.is_a?(Integer)
          Organization.find(origin_item)&.name || origin_item.to_s
        else
          Organization.find_by(name: origin_item)&.name || origin_item
        end
      end
      clean_csv_field(origen_names.join("; "))
    else
      ""
    end

    # 9. ALIANZAS (convertir IDs a nombres)
    alianzas = if org.allies.any?
      ally_names = org.allies.map do |ally_id|
        Organization.find(ally_id)&.name rescue "N/A"
      end.compact
      clean_csv_field(ally_names.join("; "))
    else
      ""
    end

    # 10. CONFLICTOS (convertir IDs a nombres)
    conflictos = if org.rivals.any?
      rival_names = org.rivals.map do |rival_id|
        Organization.find(rival_id)&.name rescue "N/A"
      end.compact
      clean_csv_field(rival_names.join("; "))
    else
      ""
    end

    # Construir fila base
    row = [
      nombre,
      estatus,
      nombres_alternos,
      siglas,
      tipo,
      subtipo,
      lider,
      origen,
      alianzas,
      conflictos
    ]

    # 11-29. ACTIVIDADES DELICTIVAS (0 o 1)
    org_divisions = org.divisions.where.not(name: "General").pluck(:name)

    ACTIVIDADES_BD.each do |activity|
      row << (org_divisions.include?(activity) ? 1 : 0)
    end

    csv << row
  end

  puts "\n✅ CSV generado exitosamente"
  puts "📝 Total de organizaciones exportadas: #{processed}"
  puts "📊 Total de filas (incluyendo encabezado): #{processed + 1}"
  puts "📋 Total de columnas: #{HEADERS.count}"
end

# Mostrar información del archivo creado
file_size = File.size(output_file) / 1024.0
puts "\n" + "=" * 80
puts "✨ RESUMEN FINAL"
puts "=" * 80
puts "📁 Archivo: #{output_file}"
puts "💾 Tamaño: #{file_size.round(2)} KB"
puts "✅ Listo para descargar\n\n"
