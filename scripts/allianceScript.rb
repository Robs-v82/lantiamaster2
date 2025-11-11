# scripts/allianceScript.rb
# Entrada:
#   - "relaciones - general.csv"
#   - "Incompatibles.csv" (cols: "Organización A", "Organización B")
# Salida:
#   1) "A. Nuevo perfil OC (DDMMAAAA).csv"
#   2) "D. Contradicciones (DDMMAAAA).csv" (solo contradicciones dentro de un mismo año, con "Relación que prevalece")
#
# Reglas:
# - Una fila por organización con columnas: Nombre, Aliados, Conflictos
# - Aliados/Conflictos: nombres separados por '; '
# - Vacíos en 2022..2025 se interpretan como 0
# - En contradicción dentro de un mismo año, gana la mayor frecuencia de ese año
#   (en empate, se elige "Conflicto")
# - Entre años: prevalece el año más reciente con actividad
# - Eliminación de incompatibles por columna (Aliados y Conflictos) por fila
# - Eliminación de organizaciones inactivas: Organization.where(active: false)
#
require "csv"
require "set"
require "time"

INPUT_FILE   = File.join(__dir__, "relaciones - general.csv")
INCOMP_FILE  = File.join(__dir__, "Incompatibles.csv")
TODAY_TAG    = Time.now.strftime("%d%m%Y")
OUTPUT_FILE  = File.join(__dir__, "A. Nuevo perfil OC (#{TODAY_TAG}).csv")
CONTRA_FILE  = File.join(__dir__, "D. Contradicciones (#{TODAY_TAG}).csv")
YEARS        = %w[2022 2023 2024 2025]

# -------- Utilidades --------

def normalize(s)
  return "" if s.nil?
  s.to_s.strip
end

def find_header(headers, regex_list, fallback = nil)
  headers.find { |h| regex_list.any? { |rx| h.to_s.downcase.match?(rx) } } || fallback
end

def safe_int(v)
  s = v.to_s.strip
  return 0 if s.empty?
  s.gsub(/[^\d-]/, "").to_i
end

def prefer_type_by_freq(freq_a, freq_c)
  # En empate, preferimos Conflicto para ser conservadores
  return "Conflicto" if freq_c > freq_a
  return "Alianza"   if freq_a > freq_c
  "Conflicto"
end

# -------- Carga de CSV principal --------

abort "No se encontró: #{INPUT_FILE}" unless File.exist?(INPUT_FILE)
csv = CSV.read(INPUT_FILE, headers: true, encoding: "bom|utf-8")
headers = csv.headers

org_a_header = find_header(headers, [/organizaci[oó]n.*a/, /organizacion.*a/])
org_b_header = find_header(headers, [/organizaci[oó]n.*b/, /organizacion.*b/])
type_header  = find_header(headers, [/^tipo\b/, /relaci[oó]n/, /relacion/])

unless org_a_header && org_b_header && type_header
  abort "No se pudieron identificar las columnas de 'Organización A', 'Organización B' y 'Tipo/Relación'.\n" \
        "Detectados:\n  Organización A: #{org_a_header.inspect}\n  Organización B: #{org_b_header.inspect}\n  Tipo/Relación:  #{type_header.inspect}"
end

year_headers = YEARS.select { |y| headers.include?(y) }
abort "No se encontraron columnas de años entre #{YEARS.join(', ')}." if year_headers.empty?

# Estructuras:
# pair_data[pair_key] = {
#   :orgs => [a,b],
#   :years => { "2022" => { "Alianza" => int, "Conflicto" => int }, ... }
# }
pair_data = {}
all_orgs  = Set.new

csv.each do |row|
  a = normalize(row[org_a_header])
  b = normalize(row[org_b_header])
  next if a.empty? || b.empty?

  type = normalize(row[type_header]).downcase
  type = case type
         when "alianza"   then "Alianza"
         when "conflicto" then "Conflicto"
         else next
         end

  all_orgs << a
  all_orgs << b

  key = [a, b].sort.join("||")
  pdata = (pair_data[key] ||= { orgs: [a, b], years: {} })

  year_headers.each do |y|
    freq = safe_int(row[y])
    next if freq <= 0
    yd = (pdata[:years][y] ||= { "Alianza" => 0, "Conflicto" => 0 })
    yd[type] += freq
  end
end

# -------- Carga de incompatibles --------
# incompatible_with[x] => Set[y1, y2, ...] (simétrico)
incompatible_with = Hash.new { |h, k| h[k] = Set.new }
if File.exist?(INCOMP_FILE)
  incsv = CSV.read(INCOMP_FILE, headers: true, encoding: "bom|utf-8")
  hA = find_header(incsv.headers, [/organizaci[oó]n.*a/, /organizacion.*a/]) || "Organización A"
  hB = find_header(incsv.headers, [/organizaci[oó]n.*b/, /organizacion.*b/]) || "Organización B"
  incsv.each do |row|
    x = normalize(row[hA])
    y = normalize(row[hB])
    next if x.empty? || y.empty?
    incompatible_with[x] << y
    incompatible_with[y] << x
  end
else
  warn "Aviso: No se encontró #{INCOMP_FILE}. Se omitirá la eliminación de incompatibles."
end

# -------- Resolución, contradicciones intra-anuales y metadatos por par --------

allies    = Hash.new { |h, k| h[k] = Set.new }
conflicts = Hash.new { |h, k| h[k] = Set.new }

# Para CSV de contradicciones intra-anuales con tipo que prevalece
# Estructura: [orgA, orgB, año, relacion_que_prevalece]
intra_year_conflicts = []

# Metadatos para decisión en incompatibles:
# relation_meta[subject][counter] = { year: "YYYY", type: "Alianza"/"Conflicto", support: Integer }
relation_meta = Hash.new { |h, k| h[k] = {} }

pair_data.each_value do |pdata|
  a, b = pdata[:orgs]
  years_map = pdata[:years]

  next if years_map.empty? || years_map.values.all? { |h| h["Alianza"].to_i == 0 && h["Conflicto"].to_i == 0 }

  # Decisión por año y registro de contradicciones SOLO dentro del mismo año
  per_year_choice = {} # "2022" => "Alianza"/"Conflicto"
  YEARS.each do |y|
    next unless years_map[y]
    fa = years_map[y]["Alianza"].to_i
    fc = years_map[y]["Conflicto"].to_i
    next if fa == 0 && fc == 0

    if fa > 0 && fc > 0
      chosen = prefer_type_by_freq(fa, fc)
      intra_year_conflicts << [a, b, y, chosen]
      per_year_choice[y] = chosen
    else
      per_year_choice[y] = (fa > 0 ? "Alianza" : "Conflicto")
    end
  end

  # Elegir el tipo definitivo por el año más reciente con actividad
  chosen_type = nil
  chosen_year = nil
  chosen_support = 0
  YEARS.reverse_each do |y|
    t = per_year_choice[y]
    if t
      chosen_type = t
      chosen_year = y
      # soporte = frecuencia del tipo elegido en ese año
      fa = years_map[y]["Alianza"].to_i
      fc = years_map[y]["Conflicto"].to_i
      chosen_support = (t == "Alianza" ? fa : fc)
      break
    end
  end
  next unless chosen_type

  # Poblar listas finales (no dirigidas) y metadatos en ambos sentidos
  if chosen_type == "Alianza"
    allies[a] << b
    allies[b] << a
  else
    conflicts[a] << b
    conflicts[b] << a
  end

  relation_meta[a][b] = { year: chosen_year, type: chosen_type, support: chosen_support }
  relation_meta[b][a] = { year: chosen_year, type: chosen_type, support: chosen_support }
end

# Asegurar presencia de todas las organizaciones
all_orgs.each do |org|
  allies[org]    ||= Set.new
  conflicts[org] ||= Set.new
end

# -------- Eliminación de incompatibles por fila/columna --------

def enforce_incompatibles!(subject_set, subject_name, incompatible_with, relation_meta)
  return unless incompatible_with && !incompatible_with.empty?
  items = subject_set.to_a
  to_remove = Set.new

  # Para cada par incompatible (x,y) presente simultáneamente en la misma columna del sujeto,
  # conservar el que tenga relación más reciente con el sujeto; si empatan en año, conservar el de mayor "support";
  # si aún empatan, conservar el lexicográficamente menor y remover el otro, para determinismo.
  items.combination(2).each do |x, y|
    next unless incompatible_with[x]&.include?(y) || incompatible_with[y]&.include?(x)

    mx = relation_meta.dig(subject_name, x) || {}
    my = relation_meta.dig(subject_name, y) || {}

    yx = mx[:year].to_s
    yy = my[:year].to_s

    if yx != "" && yy != ""
      if yx > yy
        to_remove << y
      elsif yy > yx
        to_remove << x
      else
        sx = mx[:support].to_i
        sy = my[:support].to_i
        if sx > sy
          to_remove << y
        elsif sy > sx
          to_remove << x
        else
          # determinista
          keep = [x, y].min
          rem  = (keep == x ? y : x)
          to_remove << rem
        end
      end
    else
      # Si faltan metadatos, aplicar regla determinista
      keep = [x, y].min
      rem  = (keep == x ? y : x)
      to_remove << rem
    end
  end

  to_remove.each { |z| subject_set.delete(z) }
end

all_orgs.each do |org|
  enforce_incompatibles!(allies[org],    org, incompatible_with, relation_meta)
  enforce_incompatibles!(conflicts[org], org, incompatible_with, relation_meta)
end

# -------- Eliminación de organizaciones inactivas --------
begin
  inactive_names = Organization.where(active: false).pluck(:name).map { |n| normalize(n) }.to_set
rescue => e
  warn "Aviso: No se pudo consultar Organization.where(active: false): #{e.class}: #{e.message}"
  inactive_names = Set.new
end

if inactive_names.any?
  all_orgs.each do |org|
    allies[org].delete_if    { |t| inactive_names.include?(t) }
    conflicts[org].delete_if { |t| inactive_names.include?(t) }
  end
end

# -------- Normalización de reciprocidad (debe ir antes de escribir CSVs) --------
def normalize_reciprocity!(graph)
  # graph: Hash[String => Set[String]]
  # Elimina aristas no mutuas y autolazos
  to_remove = []
  graph.each do |a, neighs|
    neighs.each do |b|
      next if a == b
      unless graph[b]&.include?(a)
        to_remove << [a, b]
      end
    end
    # quitar autolazos por si acaso
    neighs.delete(a)
  end
  to_remove.each { |a, b| graph[a].delete(b) }
end

normalize_reciprocity!(allies)
normalize_reciprocity!(conflicts)

# -------- Escritura de salidas --------

# 1) Perfil OC
CSV.open(OUTPUT_FILE, "w", write_headers: true, headers: ["Nombre", "Aliados", "Conflictos"], encoding: "utf-8") do |out|
  all_orgs.to_a.sort.each do |org|
    allies_list    = allies[org].to_a.sort.join("; ")
    conflicts_list = conflicts[org].to_a.sort.join("; ")
    out << [org, allies_list, conflicts_list]
  end
end

# 2) Contradicciones intra-anuales (con relación que prevalece)
CSV.open(CONTRA_FILE, "w", write_headers: true, headers: ["Organización A", "Organización B", "Año", "Relación que prevalece"], encoding: "utf-8") do |out|
  intra_year_conflicts
    .uniq
    .sort_by { |a1, b1, y, rel| [y, a1, b1, rel] }
    .each { |a1, b1, y, rel| out << [a1, b1, y, rel] }
end

puts "Generado: #{OUTPUT_FILE}"
puts "Generado: #{CONTRA_FILE}"
