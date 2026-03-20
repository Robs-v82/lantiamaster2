require 'csv'
existentes_nombres = []
puts "🚀 Iniciando carga Congreso Sinaloa..."

def members_similar?(member1, member2)
  fn1 = I18n.transliterate(member1.firstname.to_s.downcase)
  ln1a = I18n.transliterate(member1.lastname1.to_s.downcase)
  ln1b = I18n.transliterate(member1.lastname2.to_s.downcase)

  fn2 = I18n.transliterate(member2.firstname.to_s.downcase)
  ln2a = I18n.transliterate(member2.lastname1.to_s.downcase)
  ln2b = I18n.transliterate(member2.lastname2.to_s.downcase)

  firstname_match = fn1.include?(fn2) || fn2.include?(fn1)
  lastname1_match = ln1a.include?(ln2a) || ln2a.include?(ln1a)
  lastname2_match = ln1b.include?(ln2b) || ln2b.include?(ln1b)

  firstname_match && lastname1_match && lastname2_match
end

# =========================
# 1. PARTIDOS
# =========================
parties = [
  { name: "Partido Revolucionario Institucional", acronym: "PRI" },
  { name: "Partido Acción Nacional", acronym: "PAN" },
  { name: "Partido de la Revolución Democrática", acronym: "PRD" },
  { name: "Partido del Trabajo", acronym: "PT" },
  { name: "Partido Verde Ecologista de México", acronym: "PVEM" },
  { name: "Movimiento Regeneración Nacional", acronym: "MORENA" },
  { name: "Partido Sinaloense", acronym: "PAS" },
  { name: "Movimiento Ciudadano", acronym: "MC" },
  { name: "Partido Encuentro Social", acronym: "PES" },
  { name: "Grupo Parlamentario Plural", acronym: "GPLURAL" },
  { name: "Otro / Sin Partido", acronym: "OT" }
]

parties.each do |party|
  Organization.find_or_create_by!(acronym: party[:acronym]) do |org|
    org.name = party[:name]
  end
end

puts "✅ Partidos verificados"

# =========================
# 2. ORGANIZACIÓN CONGRESO
# =========================
congreso = Organization.find_or_create_by!(name: "Congreso de Sinaloa", county_id: 2483) do |org|
  org.acronym = "CONGRESO_SIN"
end

puts "✅ Organización Congreso lista"

# =========================
# 3. ROLE LEGISLADOR
# =========================
legislador_role = Role.find_or_create_by!(name: "Legislador")

# =========================
# 4. FECHAS POR LEGISLATURA
# =========================
fechas = {
  "LXI"  => [Date.new(2013,10,1), Date.new(2016,9,30)],
  "LXII" => [Date.new(2016,10,1), Date.new(2018,9,30)],
  "LXIII"=> [Date.new(2018,10,1), Date.new(2021,9,30)],
  "LXIV" => [Date.new(2021,10,1), Date.new(2024,9,30)],
  "LXV"  => [Date.new(2024,10,1), Date.new(2027,9,30)]
}

# =========================
# 5. CSV PATH
# =========================
csv_path = Rails.root.join("scripts", "Congreso Sinaloa.csv")

# =========================
# 6. FUNCIÓN SIMILARIDAD (reusa lógica base)
# =========================
def same_member?(m, fn, ln1, ln2)
  return false if m.firstname.blank? || m.lastname1.blank? || m.lastname2.blank?

  exact = (
    m.firstname == fn &&
    m.lastname1 == ln1 &&
    m.lastname2 == ln2
  )

  return true if exact

  members_similar?(
    m,
    OpenStruct.new(firstname: fn, lastname1: ln1, lastname2: ln2)
  )
end

# =========================
# 7. PROCESAMIENTO
# =========================
creados = 0
existentes = 0
appointments_creados = 0

CSV.foreach(csv_path, headers: true, encoding: "bom|utf-8") do |row|
  legislatura = row["legislatura"]&.strip
  firstname   = row["nombre"]&.strip
  lastname1   = row["apellido_paterno"]&.strip
  lastname2   = row["apellido_materno"]&.strip
  partido_acr = row["partido"]&.strip

  next if firstname.blank? || lastname1.blank?

  partido = Organization.find_by(acronym: partido_acr)

  # =========================
  # BUSCAR MIEMBRO
  # =========================
  candidatos = Member.where(
    firstname: firstname,
    lastname1: lastname1
  )

  match = candidatos.find do |m|
    same_member?(m, firstname, lastname1, lastname2)
  end

  # =========================
  # CREAR SI NO EXISTE
  # =========================
  if match.nil?
    match = Member.create!(
      firstname: firstname,
      lastname1: lastname1,
      lastname2: lastname2,
      organization: partido,
      role: legislador_role,
      involved: false
    )
    creados += 1
  else
    existentes += 1
    existentes_nombres << "#{firstname} #{lastname1} #{lastname2}".strip
  end

  # =========================
  # APPOINTMENT
  # =========================
  inicio, fin = fechas[legislatura]

  existing_appointment = Appointment.where(
    member_id: match.id,
    organization_id: congreso.id,
    role_id: legislador_role.id
  ).where("period && daterange(?, ?, '[]')", inicio, fin).first

  if existing_appointment.nil?
    Appointment.create!(
      member: match,
      organization: congreso,
      role: legislador_role,
      period: inicio..fin,
      start_precision: "day",
      end_precision: "day"
    )
    appointments_creados += 1
  end
end

# =========================
# RESULTADO
# =========================
puts "=============================="
puts "✅ Miembros creados: #{creados}"
puts "🔁 Miembros existentes: #{existentes}"
puts "📅 Appointments creados: #{appointments_creados}"
puts "=============================="
puts "------------------------------"
puts "📋 Miembros existentes:"
existentes_nombres.each do |nombre|
  puts "- #{nombre}"
end
puts "------------------------------"

puts "\n📰 Legisladores con al menos un hit asociado:"
members_with_hits = Member.joins(:hits)
  .joins(:appointments)
  .where(appointments: { organization_id: congreso.id, role_id: legislador_role.id })
  .distinct
  .order(:lastname1, :lastname2, :firstname)

if members_with_hits.any?
  members_with_hits.each do |member|
    puts " - #{member.firstname} #{member.lastname1} #{member.lastname2}".squish
  end
else
  puts " - Ninguno"
end