# scripts/deleteDuplicateAllies.rb
# Modifica en sitio "A.1. PERFIL OC_Corte_20251110.csv":
# 1) En cada fila, elimina de "Aliados" los nombres que también aparezcan en "Pertenencia" (Pertenencia ∩ Aliados).
# 2) En cada fila, elimina de "Pertenencia" los nombres que aparezcan en "Rivales" (Pertenencia ∩ Rivales).
#
# Ejecución:
#   load "scripts/deleteDuplicateAllies.rb"

require "csv"
require "set"
require "tempfile"

INPUT_FILE = File.join(__dir__, "A. PERFIL OC_Corte_20260110_OK - Pruebas.csv")

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

def join_list(arr)
  arr.join("; ")
end

def find_header(headers, *patterns)
  headers.find { |h| patterns.any? { |rx| h.to_s.downcase.match?(rx) } }
end

abort "No se encontró el archivo de entrada: #{INPUT_FILE}" unless File.exist?(INPUT_FILE)

csv_in  = CSV.read(INPUT_FILE, headers: true, encoding: "bom|utf-8")
headers = csv_in.headers

# Resolver encabezados tolerantes a acentos/variaciones
per_header = find_header(headers, /\bpertenencia\b/)
ali_header = find_header(headers, /\baliados?\b/)
riv_header = find_header(headers, /\brivales?\b/)

unless per_header && ali_header && riv_header
  abort "No se pudieron identificar las columnas 'Pertenencia', 'Aliados' y 'Rivales'.\n" \
        "Encabezados encontrados: #{headers.inspect}"
end

# Preparamos archivo temporal para reescritura
temp = Tempfile.new("deleteDuplicateAllies")
temp_path = temp.path
temp.close

rows_modified_allies       = 0
rows_modified_pertenencia  = 0

CSV.open(temp_path, "w", write_headers: true, headers: headers, encoding: "utf-8") do |out|
  csv_in.each do |row|
    pertenencia = split_list(row[per_header])
    aliados     = split_list(row[ali_header])
    rivales     = split_list(row[riv_header])

    # --- 1) Limpiar Aliados: quitar intersección con Pertenencia ---
    if aliados.any? && pertenencia.any?
      per_set = pertenencia.to_set
      seen = Set.new
      new_allies = []
      aliados.each do |ally|
        next if per_set.include?(ally) # quitar Pertenencia ∩ Aliados
        next if seen.include?(ally)    # quitar duplicados en Aliados
        seen << ally
        new_allies << ally
      end
      if new_allies != aliados
        rows_modified_allies += 1
      end
      row[ali_header] = join_list(new_allies)
    else
      # Normaliza formato
      row[ali_header] = join_list(aliados)
    end

    # --- 2) Limpiar Pertenencia: quitar intersección con Rivales ---
    if pertenencia.any? && rivales.any?
      riv_set = rivales.to_set
      seen_p = Set.new
      new_per = []
      pertenencia.each do |m|
        next if riv_set.include?(m)    # quitar Pertenencia ∩ Rivales
        next if seen_p.include?(m)     # quitar duplicados en Pertenencia
        seen_p << m
        new_per << m
      end
      if new_per != pertenencia
        rows_modified_pertenencia += 1
      end
      row[per_header] = join_list(new_per)
    else
      # Normaliza formato
      row[per_header] = join_list(pertenencia)
    end

    out << row
  end
end

# Reemplazar el archivo original por el temporal
File.rename(temp_path, INPUT_FILE)

puts "Proceso completado."
puts "Filas modificadas en 'Aliados' (se removió Pertenencia∩Aliados): #{rows_modified_allies}"
puts "Filas modificadas en 'Pertenencia' (se removió Pertenencia∩Rivales): #{rows_modified_pertenencia}"
