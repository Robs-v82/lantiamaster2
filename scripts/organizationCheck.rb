# scripts/organizationCheck.rb
# Ejecución:
#   load "scripts/organizationCheck.rb"

require "csv"
require "set"

INPUT_FILE = File.join(__dir__, "A. PERFIL OC_Corte_20260110_OK - Corregido.csv")

def normalize(s)
  return "" if s.nil?
  s = s.to_s.strip
  s.gsub(/\s+/, " ")
end

def split_list(val)
  s = normalize(val)
  return [] if s.empty?
  s.split(/[;,]/).map { |x| normalize(x) }.reject(&:empty?)
end

def find_header(headers, *patterns)
  headers.find { |h| patterns.any? { |rx| h.to_s.downcase.match?(rx) } }
end

unless File.exist?(INPUT_FILE)
  abort "No se encontró el archivo de entrada: #{INPUT_FILE}"
end

csv = CSV.read(INPUT_FILE, headers: true, encoding: "bom|utf-8")
headers = csv.headers

# Encabezados
den_header = find_header(headers,
  /\bdenominaci[oó]n\b/, /\bdenominacion\b/, /\bdenominación\b/, /\bnombre\b/
)
den_oc_header = find_header(headers,
  /\bdenominaci[oó]n\s*oc\b/, /\bdenominacion\s*oc\b/, /\bdenominaci[oó]n\b.*\boc\b/
)

per_header = find_header(headers, /\bpertenencia\b/)
ali_header = find_header(headers, /\baliados?\b/)
riv_header = find_header(headers, /\brivales?\b/)

unless den_header && per_header && ali_header && riv_header
  abort "No se pudieron identificar todos los encabezados requeridos.\n" \
        "Esperados (variantes): Denominación, Pertenencia, Aliados, Rivales.\n" \
        "Encabezados encontrados: #{headers.inspect}"
end

# Set con TODAS las Denominación OC del CSV (normalizadas)
den_oc_names = Set.new
if den_oc_header
  csv.each do |row|
    v = normalize(row[den_oc_header])
    den_oc_names << v unless v.empty?
  end
else
  warn "Advertencia: no se encontró el encabezado 'Denominación OC'. Se omitirá este filtro."
end

# --------- Acumuladores de hallazgos (DEBEN ir antes de imprimir) ---------
viol_per_ali = []  # [row_idx, denom, coincidencias(Set)]
viol_per_riv = []  # [row_idx, denom, coincidencias(Set)]
viol_ali_riv = []  # [row_idx, denom, coincidencias(Set)]

unknown_names = Set.new
unknown_by_row = Hash.new { |h,k| h[k] = Set.new }

# --------- Recorremos filas ---------
csv.each_with_index do |row, idx|
  row_num = idx + 1

  denom       = normalize(row[den_header])
  pertenencia = split_list(row[per_header])
  aliados     = split_list(row[ali_header])
  rivales     = split_list(row[riv_header])

  per_set = pertenencia.to_set
  ali_set = aliados.to_set
  riv_set = rivales.to_set

  inter_per_ali = per_set & ali_set
  viol_per_ali << [row_num, denom, inter_per_ali] if inter_per_ali.any?

  inter_per_riv = per_set & riv_set
  viol_per_riv << [row_num, denom, inter_per_riv] if inter_per_riv.any?

  inter_ali_riv = ali_set & riv_set
  viol_ali_riv << [row_num, denom, inter_ali_riv] if inter_ali_riv.any?

  names_to_check = []
  names_to_check.concat(pertenencia)
  names_to_check.concat(aliados)
  names_to_check.concat(rivales)

  names_to_check.each do |x|
    next if x.empty?

    # <-- AQUÍ está la corrección que pediste:
    # si el nombre aparece en "Denominación OC" del CSV, NO lo reportes como unknown
    next if den_oc_header && den_oc_names.include?(x)

    begin
      unless Organization.find_by(name: x)
        unknown_names << x
        unknown_by_row[row_num] << x
      end
    rescue => e
      warn "Advertencia: error consultando Organization.find_by(name: #{x.inspect}) en fila #{row_num}: #{e.class}: #{e.message}"
    end
  end
end

# --------- Impresión de reporte (AL FINAL) ---------
puts "\n===== REVISIÓN DE CONSISTENCIA SOBRE #{File.basename(INPUT_FILE)} =====\n\n"

puts "— Coincidencias Pertenencia ∩ Aliados —"
if viol_per_ali.empty?
  puts "  Ninguna."
else
  viol_per_ali.each do |row_num, denom, inter|
    puts "  Fila #{row_num} | Denominación: #{denom} | Coincidencias: #{inter.to_a.sort.join('; ')}"
  end
end
puts

puts "— Coincidencias Pertenencia ∩ Rivales —"
if viol_per_riv.empty?
  puts "  Ninguna."
else
  viol_per_riv.each do |row_num, denom, inter|
    puts "  Fila #{row_num} | Denominación: #{denom} | Coincidencias: #{inter.to_a.sort.join('; ')}"
  end
end
puts

puts "— Coincidencias Aliados ∩ Rivales —"
if viol_ali_riv.empty?
  puts "  Ninguna."
else
  viol_ali_riv.each do |row_num, denom, inter|
    puts "  Fila #{row_num} | Denominación: #{denom} | Coincidencias: #{inter.to_a.sort.join('; ')}"
  end
end
puts

puts "— Nombres NO encontrados en la base de datos (solo Pertenencia/Aliados/Rivales) —"
if unknown_names.empty?
  puts "  Todos los nombres fueron encontrados (o aparecen en 'Denominación OC')."
else
  unknown_by_row.keys.sort.each do |row_num|
    list = unknown_by_row[row_num].to_a.sort
    next if list.empty?
    puts "  Fila #{row_num}: #{list.join('; ')}"
  end
  puts
  puts "  Total únicos no encontrados: #{unknown_names.size}"
end
puts

puts "===== RESUMEN ====="
puts "  Filas con Pertenencia∩Aliados: #{viol_per_ali.size}"
puts "  Filas con Pertenencia∩Rivales: #{viol_per_riv.size}"
puts "  Filas con Aliados∩Rivales:     #{viol_ali_riv.size}"
puts "  Nombres únicos no encontrados:  #{unknown_names.size}"
puts "==================================\n"