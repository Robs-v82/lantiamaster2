# === Helpers de normalización y cálculo ===
targetMembers = Member.joins(:hits).distinct

# scripts/homoScoreScript.rb

# Uso:
#   # en consola
#   targetMembers = Member.where(active: true)  # o la relación que quieras
#   load "scripts/homoScoreScript.rb"

# require "unicode_normalize"

# === Helpers de normalización y cálculo ===

# Normaliza como en el JS: NFD, quita diacríticos, minúsculas
normalize = ->(s) do
  (s || "").to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
end

# Valida como el regex JS: sólo letras/espacios (incl. ÁÉÍÓÚÑÜ), mínimo 2 chars
solo_letras_regex = /\A[A-Za-zÁÉÍÓÚáéíóúÑñÜü\s]{2,}\z/

valid_text = ->(s) do
  s.is_a?(String) && s.strip.match?(solo_letras_regex)
end

# Carga diccionario de frecuencias desde BD y lo normaliza (clave normalizada => freq)
name_freqs = Name.pluck(:word, :freq).each_with_object({}) do |(w, f), h|
  h[normalize.call(w)] = f
end

# Busca la frecuencia replicando el "includes" del JS
freq_for = ->(texto) do
  return 5 unless valid_text.call(texto)

  norm = normalize.call(texto)
  matched_key = name_freqs.keys.find { |k| norm.include?(k) || k.include?(norm) }
  matched_key ? name_freqs[matched_key] : 5
end

# Calcula homo_score como en JS: Math.round((f1*f2*f3)/10000)
homo_score_for = ->(member) do
  f1 = freq_for.call(member.firstname)
  f2 = freq_for.call(member.lastname1)
  f3 = freq_for.call(member.lastname2)

  if valid_text.call(member.firstname) && valid_text.call(member.lastname1) && valid_text.call(member.lastname2)
    ((f1 * f2 * f3) / 10000.0).round
  else
    nil
  end
end

# Mapea homo_score a rango de estimación (idéntico a tu case)
rango_label = ->(score) do
  return nil if score.nil?
  case score
  when 0...2 then "sólo 1"
  when 2...3 then "más de 2"
  when 3...4 then "más de 3"
  when 4...5 then "más de 4"
  when 5...6 then "más de 5"
  when 6...7 then "más de 6"
  when 7...8 then "más de 7"
  when 8...9 then "más de 8"
  when 9...10 then "más de 9"
  when 10...20 then "más de 10"
  when 20...30 then "más de 20"
  when 30...40 then "más de 30"
  when 40...50 then "más de 40"
  when 50...60 then "más de 50"
  when 60...70 then "más de 60"
  when 70...80 then "más de 70"
  when 80...90 then "más de 80"
  when 90...100 then "más de 90"
  when 100...200 then "más de 100"
  when 200...500 then "más de 200"
  when 500...1000 then "más de 500"
  else "más de 1000"
  end
end

ORDER = [
  "sólo 1",
  "más de 2","más de 3","más de 4","más de 5","más de 6","más de 7","más de 8","más de 9",
  "más de 10","más de 20","más de 30","más de 40","más de 50","más de 60","más de 70","más de 80","más de 90",
  "más de 100","más de 200","más de 500","más de 1000"
]

unless defined?(targetMembers)
  raise 'Define primero targetMembers (ej. targetMembers = Member.limit(500))'
end

freq_table = Hash.new(0)
total_procesados = 0
omitidos_invalidos = 0
muestra = []

# Itera eficientemente si es relación ActiveRecord que permite batches; sino, usa each
enumerador =
  if targetMembers.respond_to?(:find_each)
    enum_for(:find_each, targetMembers)
  else
    targetMembers.each
  end

# Implementación de find_each sobre una relación, si aplica
def find_each(rel)
  if rel.is_a?(ActiveRecord::Relation)
    rel.find_each(batch_size: 1000) { |rec| yield rec }
  else
    rel.each { |rec| yield rec }
  end
end

# Procesamiento
find_each(targetMembers) do |m|
  score = homo_score_for.call(m)
  if score.nil?
    omitidos_invalidos += 1
    next
  end

  etiqueta = rango_label.call(score)
  freq_table[etiqueta] += 1
  total_procesados += 1

  if muestra.size < 20
    muestra << {
      id: m.id,
      firstname: m.firstname,
      lastname1: m.lastname1,
      lastname2: m.lastname2,
      homo_score: score,
      rango: etiqueta
    }
  end
end

# Salida
puts "=== Muestra de miembros y su homo_score (máx 20) ==="
muestra.each do |row|
  puts "##{row[:id]} | #{row[:firstname]} #{row[:lastname1]} #{row[:lastname2]} | score: #{row[:homo_score]} | rango: #{row[:rango]}"
end
puts

puts "=== Tabla de frecuencias (#{total_procesados} miembros válidos; omitidos: #{omitidos_invalidos}) ==="
ORDER.each do |label|
  count = freq_table[label] || 0
  printf("%-12s : %d\n", label, count)
end

tabla_ordenada = ORDER.map { |lbl| [lbl, freq_table[lbl] || 0] }.to_h
puts
puts "Hash de frecuencias ordenado:"
pp tabla_ordenada


