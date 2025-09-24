require 'csv'

csv_path = Rails.root.join("scripts", "Lideres taxistas - Plataforma.csv")
unless File.exist?(csv_path)
  puts "❌ Archivo no encontrado: #{csv_path}"
  exit
end

role_id = Role.find_or_create_by(name: "Dirigente sindical").id

CSV.foreach(csv_path, headers: true) do |row|
  firstname = row["member.firstname"].to_s.strip
  lastname1 = row["member.lastname1"].to_s.strip
  lastname2 = row["member.lastname2"].to_s.strip

  start_date = nil
  if row["member.start_date"].present?
    begin
      start_date = Date.parse(row["member.start_date"])
    rescue ArgumentError
      puts "⚠️ Fecha inválida para #{firstname} #{lastname1}: #{row['member.start_date']}"
    end
  end

  organization_id = Organization.find_or_create_by(name: row["organization.name"]).id

  criminal_link = Organization.find_by(name: row["criminal_link"])
  unless criminal_link
    puts "❌ #{row['criminal_link']} NO existe"
    next
  end

  if Member.exists?(firstname: firstname, lastname1: lastname1, lastname2: lastname2)
    puts "❌ #{firstname} #{lastname1} ya existe"
    next
  end

  member = Member.create!(
    firstname: firstname,
    lastname1: lastname1,
    lastname2: lastname2,
    start_date: start_date,
    organization_id: organization_id,
    criminal_link_id: criminal_link.id,
    role_id: role_id,
    involved: false
  )

  # Buscar town desde full_code en el CSV
  full_code = row["county.full_code"]+"0000"
  town = Town.find_by(full_code: full_code)
  unless town
    puts "⚠️ No se encontró municipio con código #{row["county.full_code"]}"
    next
  end

  legacy_prefix = start_date ? start_date.strftime("%Y%m%d") : "SINFECHA"
  legacy_random = SecureRandom.hex(4)
  legacy_id = "AUTO-#{legacy_prefix}-#{legacy_random}"

  hit = Hit.create!(
    date: start_date,
    town_id: town.id,
    title: "Nombramiento/toma de protesta",
    legacy_id: legacy_id
  )

  hit.members << member
  puts "✅ #{firstname} #{lastname1} creado con hit #{legacy_id}"
end

r = Role.find_by(:name=>"Alcalde")
targets = r.members.where(involved: true).where.not(:criminal_link=>nil).where.not(id: MemberRelationship.select(:member_a_id)).where.not(id: MemberRelationship.select(:member_b_id))
targets.find_each { |m|
  unless m.organization.county.nil?
  puts m.fullname+","+m.organization.county.name+","+m.criminal_link.name
  end
}



