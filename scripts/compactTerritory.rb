# scripts/compactTerritory.rb
# Lee:  "B. PRESENCIA ESTATAL-MUNICIPAL OC_20251110.csv"
# Escribe: "B. Presencia (DDMMAAAA).csv"
#
# Salida con 3 columnas:
#   1) "Clave Municipio"    (igual al original)
#   2) "OC Identificada"    (igual al original; se valida existencia en BD)
#   3) "Colonias"           (lista compactada, separada por '; ')
#
# Reglas:
# - Una sola fila por par (Clave Municipio, OC Identificada).
# - "Colonias" es la unión de lo que aparezca en columnas "Acumulado" y años 2023..2025
#   (y cualquier encabezado que contenga "colonia").
# - Se IGNORAN tokens puramente numéricos (ej. "1") al extraer colonias.
# - Si hay presencia en un municipio pero no se mencionan colonias, la columna se deja en blanco.
# - Al final imprime:
#     * número de filas del archivo original,
#     * número de filas del archivo compactado,
#     * número y nombres de organizaciones no encontradas en la BD.
#
# Ejecución en consola Rails:
#   load "scripts/compactTerritory.rb"

require "csv"
require "set"
require "time"

INPUT_FILE  = File.join(__dir__, "B. PRESENCIA ESTATAL-MUNICIPAL OC_20251110.csv")
TODAY_TAG   = Time.now.strftime("%d%m%Y")
OUTPUT_FILE = File.join(__dir__, "B. Presencia (#{TODAY_TAG}).csv")

def normalize(s)
  return "" if s.nil?
  s.to_s.strip.gsub(/\s+/, " ")
end

def find_header(headers, *patterns)
  headers.find { |h| patterns.any? { |rx| h.to_s.downcase.match?(rx) } }
end

def colonia_tokens_from(value)
  s = normalize(value)
  return [] if s.empty?
  # Separa por ; , | / salto de línea o tab
  tokens = s.split(/[;,\|\n\/\t]/).map { |x| normalize(x) }.reject(&:empty?)
  # Ignorar tokens puramente numéricos (evita que '1' se vuelva colonia)
  tokens.reject { |t| t.match?(/\A\d+\z/) }
end

abort "No se encontró el archivo de entrada: #{INPUT_FILE}" unless File.exist?(INPUT_FILE)

csv_in  = CSV.read(INPUT_FILE, headers: true, encoding: "bom|utf-8")
headers = csv_in.headers

# Encabezados esenciales
clave_header = find_header(headers, /\bclave\s*municipio\b/, /\bmunicipio.*clave\b/)
org_header   = find_header(headers, /\boc\s*identificada\b/, /\boc\b.*identificada\b/, /\borgan(?:izaci[oó]n|izacion).*identificada\b/)

unless clave_header && org_header
  abort "No se identificaron encabezados de 'Clave Municipio' y/o 'OC Identificada'.\nVimos: #{headers.inspect}"
end

# Columnas para colonias:
# - Acumulado
# - 2023, 2024, 2025 (cualquier columna cuyo encabezado contenga esos años)
# - Cualquier encabezado que contenga 'colonia'
colonia_cols = []
headers.each do |h|
  next if h.nil?
  name = h.to_s
  down = name.downcase
  if down.include?("acumulado") ||
     down.match?(/\b2023\b/) || down.match?(/\b2024\b/) || down.match?(/\b2025\b/) ||
     down.include?("colonia")
    colonia_cols << h
  end
end
colonia_cols.uniq!
abort "No se detectaron columnas para colonias (Acumulado / 2023..2025 / 'colonia')." if colonia_cols.empty?

original_rows = csv_in.size

# Agrupación por [clave_municipio, org]
Group = Struct.new(:clave, :org, :col_order, :col_seen_ci)
groups = {}  # key => Group

orgs_seen = Set.new

csv_in.each do |row|
  clave = normalize(row[clave_header])
  org   = normalize(row[org_header])
  next if clave.empty? || org.empty?

  orgs_seen << org

  key = "#{clave}\u0001#{org}"
  g = groups[key]
  unless g
    g = Group.new(clave, org, [], Set.new)
    groups[key] = g
  end

  # Extraer colonias desde las columnas definidas
  colonia_cols.each do |h|
    tokens = colonia_tokens_from(row[h])
    tokens.each do |tok|
      ci = tok.downcase
      next if g.col_seen_ci.include?(ci)
      g.col_seen_ci << ci
      g.col_order << tok
    end
  end
end

# Validar organizaciones en BD
not_found = Set.new
begin
  cache = {}
  orgs_seen.each do |name|
    begin
      cache[name] = !!Organization.find_by(name: name)
    rescue => e
      warn "Advertencia al consultar Organization.find_by(name: #{name.inspect}): #{e.class}: #{e.message}"
      cache[name] = false
    end
    not_found << name unless cache[name]
  end
rescue => e
  warn "Aviso: No se pudo validar organizaciones: #{e.class}: #{e.message}"
  not_found = Set.new
end

# Escribir archivo compacto (sobreescribe si ya existe)
CSV.open(OUTPUT_FILE, "w", write_headers: true, headers: ["Clave Municipio", "OC Identificada", "Colonias"], encoding: "utf-8") do |out|
  groups.values
        .sort_by { |g| [g.clave, g.org] }
        .each do |g|
          colonias = g.col_order.join("; ")
          out << [g.clave, g.org, colonias]
        end
end

compacted_rows = groups.size

# -------- Reporte en consola --------
puts "Generado (sobrescrito si existía): #{OUTPUT_FILE}"
puts "Filas en archivo original:  #{original_rows}"
puts "Filas en archivo compacto:  #{compacted_rows}"

if not_found.any?
  list = not_found.to_a.sort
  puts "Organizaciones NO encontradas en BD (#{list.size}):"
  puts "  - " + list.join("\n  - ")
else
  puts "Todas las organizaciones del archivo existen en la BD."
end
