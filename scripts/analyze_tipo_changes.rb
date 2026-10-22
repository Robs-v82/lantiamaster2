#!/usr/bin/env ruby
# Script para analizar cambios en la columna TIPO entre junio y julio
# Uso: rails runner scripts/analyze_tipo_changes.rb

require 'csv'

# Rutas de los archivos
junio_file = "/Users/robertovalladares/Downloads/A. PERFIL OC_Corte_20260610_OK_CORREGIDO_15062026 - A. PERFIL OC_Corte_20260610_OK_CORREGIDO_15062026.csv"
julio_file = "/Users/robertovalladares/Downloads/A. PERFIL OC_Corte_20260710_OK - A. PERFIL OC_Corte_20260710_OK (1).csv"

puts "=" * 80
puts "ANÁLISIS DE CAMBIOS EN COLUMNA 'TIPO' - JUNIO vs JULIO"
puts "=" * 80
puts "\nLeyendo archivos..."

# Leer encabezados del archivo de junio
encabezados = nil
linea_1_junio = File.open(junio_file) { |f| f.readline.strip }
if linea_1_junio.include?("Denominación OC")
  encabezados = linea_1_junio.split(',').map(&:strip)
end

unless encabezados
  puts "❌ Error: No se encontraron encabezados válidos"
  exit 1
end

# Índices de columnas importantes
nombre_idx = encabezados.index("Denominación OC")
tipo_idx = encabezados.index("Tipo")

unless nombre_idx && tipo_idx
  puts "❌ Error: No se encontraron las columnas 'Denominación OC' o 'Tipo'"
  puts "Encabezados encontrados: #{encabezados.first(10).inspect}"
  exit 1
end

# Leer datos de junio (saltando encabezado)
junio_data = {}
CSV.foreach(junio_file, headers: encabezados, encoding: 'UTF-8') do |row|
  nombre = row['Denominación OC']&.strip
  tipo = row['Tipo']&.strip
  junio_data[nombre] = tipo if nombre && tipo
end
puts "✅ Junio: #{junio_data.count} organizaciones"

# Leer datos de julio (sin encabezados - agregar encabezados manualmente)
julio_data = {}
CSV.foreach(julio_file, headers: encabezados, encoding: 'UTF-8') do |row|
  nombre = row['Denominación OC']&.strip
  tipo = row['Tipo']&.strip
  julio_data[nombre] = tipo if nombre && tipo
end
puts "✅ Julio: #{julio_data.count} organizaciones"

# Identificar cambios
cambios = {}
organizaciones_sin_cambios = 0

puts "\nAnalizando cambios..."

junio_data.each do |nombre, tipo_junio|
  if julio_data.key?(nombre)
    tipo_julio = julio_data[nombre]

    if tipo_junio != tipo_julio
      # Hay cambio
      cambio_clave = "Cambiaron de #{tipo_junio} a #{tipo_julio}"
      cambios[cambio_clave] ||= []
      cambios[cambio_clave] << nombre
    else
      organizaciones_sin_cambios += 1
    end
  end
end

# Mostrar resultados
puts "\n" + "=" * 80
puts "RESULTADOS - CAMBIOS EN COLUMNA 'TIPO'"
puts "=" * 80

if cambios.empty?
  puts "\n✅ No hay cambios en la columna TIPO"
else
  puts "\n📊 Cambios detectados: #{cambios.values.flatten.count} organizaciones\n"

  cambios.sort.each do |cambio_clave, nombres|
    puts "\n#{cambio_clave.upcase} (#{nombres.count} organizaciones)"
    puts "-" * 80
    nombres.sort.each do |nombre|
      puts "  • #{nombre}"
    end
  end
end

puts "\n" + "=" * 80
puts "RESUMEN ESTADÍSTICO"
puts "=" * 80
puts "\nOrganizaciones sin cambios en TIPO: #{organizaciones_sin_cambios}"
puts "Organizaciones con cambios en TIPO: #{cambios.values.flatten.count}"
puts "Total analizado: #{junio_data.count}"
puts ""
