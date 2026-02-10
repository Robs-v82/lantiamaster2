# script/checkMajorScript.rb

# --- Silenciar logs (solo en development) ---
_original_logger = nil

if Rails.env.development?
  _original_logger = ActiveRecord::Base.logger
  ActiveRecord::Base.logger = Logger.new(nil)

  Rails.logger.level = Logger::FATAL if Rails.logger
end

at_exit do
  if Rails.env.development? && _original_logger
    ActiveRecord::Base.logger = _original_logger
  end
end

# ------------------------------------------------------------
# Helpers de formato (para output "pegable" en Google Docs)
# ------------------------------------------------------------
def section_title(title)
  puts "\n#{title}\n" + ("-" * title.length) + "\n\n"
end

def state_subtitle(state_name, count)
  puts "#{state_name} (#{count})"
end

def safe_criminal_link(member)
  member.criminal_link&.name.presence || "Por definir"
end

def current_appointment_for(member, role_name, today)
  # Evita N+1: usa appointments precargados (includes)
  member.appointments.find do |a|
    a.role&.name == role_name &&
      a.period.present? &&
      a.period.cover?(today)
  end
end

def location_for(member, role_name, today, include_municipio: false)
  appt = current_appointment_for(member, role_name, today)

  county = appt&.county || member.organization&.county
  state  = county&.state

  municipio = county&.name
  estado    = state&.name

  if include_municipio
    parts = []
    parts << municipio if municipio.present?
    parts << estado if estado.present?
    return parts.join(", ").presence || "SIN UBICACIÓN"
  end

  return estado.presence || "SIN ESTADO"
end

def line_for(member, role_name, today, include_municipio: false)
  name = member.fullname.to_s.strip
  return nil if name.blank?

  criminal = safe_criminal_link(member)

  case role_name
  when "Alcalde"
    # Nombre — Alcalde de Municipio, Estado — CriminalLink
    loc = location_for(member, role_name, today, include_municipio: true)
    "#{name} — Alcalde de #{loc} — #{criminal}"
  when "Gobernador"
    # Nombre — Gobernador de Estado — CriminalLink
    loc = location_for(member, role_name, today, include_municipio: false)
    "#{name} — Gobernador de #{loc} — #{criminal}"
  when "Legislador"
    # Senadores: SOLO nombre + grupo criminal (sin estado)
    "#{name} — #{criminal}"
  else
    loc = location_for(member, role_name, today, include_municipio: include_municipio)
    "#{name} — #{loc} — #{criminal}"
  end
end

def print_grouped_by_state(members, role_name, today, include_municipio: false)
  grouped = members.group_by do |m|
    # Para agrupar en el mismo criterio: estado (appointment vigente; fallback organización)
    location_for(m, role_name, today, include_municipio: false)
  end

  grouped.keys.sort.each do |state_name|
    members_in_state = grouped[state_name]
    state_subtitle(state_name, members_in_state.size)

    lines = members_in_state
      .map { |m| line_for(m, role_name, today, include_municipio: include_municipio) }
      .compact
      .sort

    lines.each { |l| puts "- #{l}" }
    puts "" # espacio entre estados
  end

  grouped
end

def print_table_state_frequency(grouped_by_state, label_count: "PERSONAS")
  rows = grouped_by_state
    .map { |state, members| [state.to_s, members.size] }
    .sort_by { |state, count| [-count, state] }

  puts "TABLA 1. Frecuencia por estado"

  col1 = "ESTADO"
  col2 = label_count.upcase

  max1 = ([col1.length] + rows.map { |r| r[0].length }).max
  max2 = ([col2.length] + rows.map { |r| r[1].to_s.length }).max

  puts "#{col1.ljust(max1)} | #{col2.rjust(max2)}"
  puts "#{'-' * max1}-+-#{'-' * max2}"

  rows.each do |state, count|
    puts "#{state.ljust(max1)} | #{count.to_s.rjust(max2)}"
  end

  puts "\n"
end

def print_table_criminal_frequency(members, label_count: "PERSONAS")
  grouped = members.group_by { |m| safe_criminal_link(m).to_s }

  rows = grouped
    .map { |cl, ms| [cl.to_s, ms.size] }
    .sort_by { |cl, count| [-count, cl] }

  puts "TABLA 2. Frecuencia por grupo criminal"

  col1 = "GRUPO CRIMINAL"
  col2 = label_count.upcase

  max1 = ([col1.length] + rows.map { |r| r[0].length }).max
  max2 = ([col2.length] + rows.map { |r| r[1].to_s.length }).max

  puts "#{col1.ljust(max1)} | #{col2.rjust(max2)}"
  puts "#{'-' * max1}-+-#{'-' * max2}"

  rows.each do |cl, count|
    puts "#{cl.ljust(max1)} | #{count.to_s.rjust(max2)}"
  end

  puts "\n"
end


# ------------------------------------------------------------
# Relaciones: detectar miembros SIN vínculos con "Familiar"
# ------------------------------------------------------------
def related_member_from(rel, member)
  # Intenta cubrir patrones comunes sin acoplarse a un esquema único.
  # Devuelve el "otro" member relacionado con +member+ dentro de +rel+.
  return rel.other_member(member) if rel.respond_to?(:other_member)
  return rel.other(member) if rel.respond_to?(:other)

  if rel.respond_to?(:member) && rel.respond_to?(:related_member)
    return (rel.member == member) ? rel.related_member : rel.member
  end

  if rel.respond_to?(:member_a) && rel.respond_to?(:member_b)
    return (rel.member_a == member) ? rel.member_b : rel.member_a
  end

  if rel.respond_to?(:member1) && rel.respond_to?(:member2)
    return (rel.member1 == member) ? rel.member2 : rel.member1
  end

  nil
end

def has_familiar_relationship?(member, familiar_role)
  return false unless member.respond_to?(:all_relationships)

  member.all_relationships.any? do |rel|
    other = related_member_from(rel, member)
    next false unless other

    other_role = other.respond_to?(:role) ? other.role : nil
    other_role == familiar_role || other_role&.name == "Familiar"
  end
end

def members_without_familiar_relationships(members)
  familiar_role = Role.find_by(name: "Familiar")
  return members.to_a if familiar_role.nil? # si no existe el rol, los trata como "sin familiar"

  members.select { |m| !has_familiar_relationship?(m, familiar_role) }
end

def print_no_familiar_section(members, role_name, today, include_municipio: false)
  no_fam = members_without_familiar_relationships(members)

  puts "CASOS SIN RELACIÓN CON 'Familiar'"
  puts "Total: #{no_fam.size}\n\n"

  lines = no_fam
    .map { |m| line_for(m, role_name, today, include_municipio: include_municipio) }
    .compact
    .sort

  if lines.empty?
    puts "- (ninguno)\n\n"
    return
  end

  lines.each { |l| puts "- #{l}" }
  puts "\n"
end

# ------------------------------------------------------------
# Universo base
# ------------------------------------------------------------
targetMembers = Member.joins(:hits).distinct

today = Date.current
three_years_ago = 3.years.ago.to_date

# ------------------------------------------------------------
# Runner genérico por rol
# ------------------------------------------------------------
def fetch_members_for_role(role_name, target_members_relation, three_years_ago)
  # 1) Appointment vigente hoy
  set1 = Member
    .where(id: target_members_relation.select(:id))
    .where(involved: true)
    .joins(appointments: :role)
    .where(roles: { name: role_name })
    .merge(Appointment.current)
    .distinct

  # 2) Role en Member + hit reciente + sin appointment concluido
  concluded_appointment_member_ids = Appointment
    .joins(:role)
    .where(roles: { name: role_name })
    .where("upper(period) IS NOT NULL AND upper(period) <= CURRENT_DATE")
    .select(:member_id)

  set2 = Member
    .where(id: target_members_relation.select(:id))
    .where(involved: true)
    .joins(:role)
    .where(roles: { name: role_name })
    .joins(:hits)
    .group("members.id")
    .having("MAX(hits.date) >= ?", three_years_ago)
    .where.not(id: concluded_appointment_member_ids)
    .distinct

  final_ids = (set1.pluck(:id) + set2.pluck(:id)).uniq

  Member
    .where(id: final_ids)
    .includes(
      :role,
      :hits,
      :criminal_link,
      appointments: [:role, :organization, :county],
      organization: { county: :state }
    )
end

# ------------------------------------------------------------
# ALCALDES
# ------------------------------------------------------------
mayors = fetch_members_for_role("Alcalde", targetMembers, three_years_ago)

section_title("ALCALDES")
puts "Total: #{mayors.count}\n\n"

grouped_mayors = print_grouped_by_state(mayors, "Alcalde", today, include_municipio: true)

# Tablas SOLO para alcaldes
print_table_state_frequency(grouped_mayors, label_count: "Alcaldes")
print_table_criminal_frequency(mayors, label_count: "Alcaldes")

print_no_familiar_section(mayors, "Alcalde", today, include_municipio: true)

# ------------------------------------------------------------
# GOBERNADORES
# ------------------------------------------------------------
governors = fetch_members_for_role("Gobernador", targetMembers, three_years_ago)

section_title("GOBERNADORES")
puts "Total: #{governors.count}\n\n"

# Listado simple (sin desagregar por estado). La línea ya incluye el estado.
gov_lines = governors
  .map { |m| line_for(m, "Gobernador", today, include_municipio: false) }
  .compact
  .sort

gov_lines.each { |l| puts "- #{l}" }
puts "\n"

print_no_familiar_section(governors, "Gobernador", today, include_municipio: false)

# ------------------------------------------------------------
# SENADORES (rol "Legislador" en tu modelo)
# ------------------------------------------------------------
senators = fetch_members_for_role("Legislador", targetMembers, three_years_ago)


section_title("SENADORES")
puts "Total: #{senators.count}\n\n"


# Listado simple (sin desagregar por estado). La línea NO incluye estado.
sen_lines = senators
.map { |m| line_for(m, "Legislador", today, include_municipio: false) }
.compact
.sort


sen_lines.each { |l| puts "- #{l}" }
puts "\n"

print_no_familiar_section(senators, "Legislador", today, include_municipio: false)

# Devuelve colecciones para inspección rápida en consola (si lo corres desde rails runner)
return {
mayors: mayors,
governors: governors,
senators: senators
}


