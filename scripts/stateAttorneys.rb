require 'csv'
require 'securerandom'

file_path = 'Delegados FGR.csv'

CRIMINAL_MAP = {
  "Baja California" => "Cártel de Sinaloa",
  "Sinaloa" => "Cártel de Sinaloa",
  "Chihuahua" => "Cártel de Sinaloa",
  "Tamaulipas" => "Los Zetas",
  "Jalisco" => "Cártel Jalisco Nueva Generación",
  "Guerrero" => "Guerreros Unidos",
  "Michoacán" => "Los Caballeros Templarios"
}

fgr = Organization.find_by(name: "Fiscalía General de la República")
delegado_role = Role.find_by(name: "Delegado estatal")
user = User.find_by(mail: "roberto@lantiaintelligence.com")

updated_members = []

CSV.foreach(file_path, headers: true) do |row|
  state_name = row["state.name"]
  state_code = row["state.code"]
  firstname = row["member.firstname"].strip
  lastname1 = row["member.lastname1"].strip
  lastname2 = row["member.lastname2"].strip
  start_date = Date.parse(row["member.start_date"])
  end_date = Date.parse(row["member.end_date"])

  member = Member.find_by(firstname: firstname, lastname1: lastname1, lastname2: lastname2)

  if member
    member.update(
      start_date: start_date,
      end_date: end_date,
      criminal_link: member.organization,
      organization: fgr,
      involved: true,
      role: delegado_role
    )
    updated_members << "#{firstname} #{lastname1} #{lastname2}"
  else
    criminal_name = CRIMINAL_MAP[state_name]
    criminal_org = Organization.find_by(name: criminal_name)

    member = Member.create(
      firstname: firstname,
      lastname1: lastname1,
      lastname2: lastname2,
      start_date: start_date,
      end_date: end_date,
      organization: fgr,
      criminal_link: criminal_org,
      involved: false,
      role: delegado_role
    )
  end

  state = State.find_by(code: state_code)
  full_code = state.capital.full_code + "0000"
  town = Town.find_by(full_code: full_code)

  # Asignación de legacy_id único con fecha y random string
  unique_legacy = "#{start_date.strftime('%Y%m%d')}-#{SecureRandom.hex(4)}"

  hit = Hit.create(
    date: start_date,
    user: user,
    title: "Nombramiento PGR/FGR",
    town: town,
    legacy_id: unique_legacy
  )

  member.hits << hit unless member.hits.include?(hit)
end

puts "Carga completa de delegados FGR."
puts "\nDelegados que ya existían y fueron actualizados:"
updated_members.each { |name| puts "- #{name}" }


