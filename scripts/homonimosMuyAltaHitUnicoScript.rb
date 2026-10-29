# Lista members que cumplen:
#   - Probabilidad de homónimos "Muy alta" (misma lógica que datasets/members_search)
#   - Exactamente un hit asociado, con fecha <= 2020-01-01
#   - criminal_role = "Miembro"
#   - En el listado de "sin respaldo" de datasets/easy_hits
# Ordenados del hit más antiguo al más reciente.
#
# Uso (desarrollo):
#   bin/rails runner scripts/homonimosMuyAltaHitUnicoScript.rb

CUTOFF_DATE = Date.new(2020, 1, 1)
TOP_N = 10

# --- Helpers alineados con app/javascript/custom/index.js ---

def normalize_str(s)
  (s || "").strip.unicode_normalize(:nfd).gsub(/[̀-ͯ]/, "").downcase
end

# Equivale a window.nameFrequencies (keys = word.capitalize en members_search)
NAME_FREQS = {}
NAME_ENTRIES = []
Name.order(:id).pluck(:word, :freq).each do |word, freq|
  key = normalize_str(word)
  NAME_FREQS[key] ||= freq
  NAME_ENTRIES << [key, freq]
end

def freq_value(raw)
  val = raw.to_f
  val.zero? ? 5 : val
end

# exact > contained (key dentro del input) > containing (input dentro de key)
def pick_freq(norm)
  return 5 if norm.empty?

  return freq_value(NAME_FREQS[norm]) if NAME_FREQS.key?(norm)

  contained = NAME_ENTRIES.each_with_index
                          .select { |(kn, _f), _i| norm.include?(kn) }
                          .sort_by { |(kn, _f), i| [-kn.length, i] }
  return freq_value(contained.first[0][1]) if contained.any?

  containing = NAME_ENTRIES.each_with_index
                           .select { |(kn, _f), _i| kn.include?(norm) }
                           .sort_by { |(kn, _f), i| [-kn.length, i] }
  return freq_value(containing.first[0][1]) if containing.any?

  5
end

# Nombres compuestos: max/avg + bono capado
def compound_freq(raw)
  norm = normalize_str(raw)
  parts = norm.split(/\s+/).reject(&:empty?)
  return pick_freq(norm) if parts.size <= 1

  part_freqs = parts.map { |p| pick_freq(p) }
  maxf = part_freqs.max
  avgf = part_freqs.sum / part_freqs.size.to_f
  bonus = [0.10 * (parts.size - 1), 0.30].min
  ((([avgf, maxf].max) * (1.0 + bonus)) + 0.5).floor # equivale a Math.round de JS
end

def homonimo_score(member)
  f_first = compound_freq(member.firstname)
  f_last1 = pick_freq(normalize_str(member.lastname1))
  f_last2 = pick_freq(normalize_str(member.lastname2))
  ((f_first * f_last1 * f_last2) / 10_000.0 + 0.5).floor
end

# Misma regla que members_search: Baja <2, Media <5, Alta <=10, Muy alta >10
def muy_alta?(score)
  score > 10
end

# --- Filtro "sin respaldo" de datasets#easy_hits ---

sin_respaldo_ids = Member.joins(:hits)
                         .where(hits: { backup_status: "ok" })
                         .distinct
                         .select(:id)

candidates = Member.joins(:hits)
                   .left_joins(:notes)
                   .where(notes: { id: nil })
                   .where.not(id: sin_respaldo_ids)
                   .where(criminal_role: "Miembro")
                   .distinct
                   .includes(:hits)
                   .to_a

rows = candidates.filter_map do |member|
  hits = member.hits.to_a
  next unless hits.size == 1

  hit = hits.first
  next if hit.date.nil? || hit.date > CUTOFF_DATE

  score = homonimo_score(member)
  next unless muy_alta?(score)

  { member: member, hit: hit, score: score }
end

sorted = rows.sort_by { |r| [r[:hit].date, r[:member].id] }

puts "Members que cumplen los criterios: #{sorted.size}"
puts "-" * 100
sorted.each_with_index do |r, i|
  m = r[:member]
  puts format("%3d. %-45s id=%-7s hit=%-7s fecha=%s score=%s",
              i + 1, m.fullname, m.id, r[:hit].id, r[:hit].date, r[:score])
end

puts "-" * 100
puts "Top #{TOP_N} (nombres completos):"
sorted.first(TOP_N).each { |r| puts "#{r[:member].id} - #{r[:member].fullname}" }
