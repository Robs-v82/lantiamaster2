# scripts/uploadOfficers.rb

puts "Cargando script: uploadOfficers.rb"

# Paso 1: Obtener todos los gobernadores
myGovernors = Member.joins(:organization)
                    .where(organizations: { league: "CONAGO" })

puts "Gobernadores identificados: #{myGovernors.size}"

# Paso 2: Obtener miembros con al menos un hit
myMembers = Member.joins(:hits).distinct

puts "Miembros con hits: #{myMembers.size}"

# Paso 3: Comparación e identificación de duplicados
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

puts "Buscando duplicados y fusionando información..."

ActiveRecord::Base.transaction do
  myMembers.each do |member|
    myGovernors.each do |governor|
      next if member.id == governor.id

      exact_match = member.firstname == governor.firstname &&
                    member.lastname1 == governor.lastname1 &&
                    member.lastname2 == governor.lastname2

      similar_match = !exact_match && members_similar?(member, governor)

      if exact_match || similar_match
        tipo = exact_match ? "Idéntico" : "Similar"

        # 1) Transferencia de atributos si existen
        governor.member_id ||= member.member_id if member.member_id.present?
        governor.media_score ||= member.media_score unless member.media_score.nil?
        governor.start_date ||= member.start_date if member.start_date.present?
        governor.end_date ||= member.end_date if member.end_date.present?
        governor.involved = true if member.involved

        # 2) Asignar criminal_link
        if member.organization_id.present?
          governor.criminal_link ||= member.organization_id
        end

        # 3) Transferencia de hits
        member.hits.each do |hit|
          unless governor.hits.include?(hit)
            governor.hits << hit
          end
        end

        governor.save!

        # 4) Eliminar al member original
        member_id = member.id
        member.destroy

        # 5) Imprimir información detallada
        puts "Fusionado y eliminado duplicado (#{tipo}):"
        puts "- Gobernador ID: #{governor.id} | #{governor.firstname} #{governor.lastname1} #{governor.lastname2} (#{governor.organization&.name})"
        puts "- Eliminado Member ID: #{member_id}"
        puts "- Hits transferidos: #{member.hits.size}"
        puts "- criminal_link asignado: #{governor.criminal_link}" if governor.criminal_link
        puts "- member_id asignado: #{governor.member_id}" if governor.member_id
        puts "- start_date: #{governor.start_date}, end_date: #{governor.end_date}"
        puts "- involved: #{governor.involved}"
        puts "-------------------------------------------------------------"
      end
    end
  end
end

puts "Primera etapa finalizada."

# scripts/uploadOfficers.rb (segunda etapa)

require 'csv'

puts "Iniciando segunda etapa: procesamiento de gobernadores desde CSV"

# Ruta del archivo
csv_path = Rails.root.join("scripts", "Gobernadores - Plataforma.csv")

unless File.exist?(csv_path)
  puts "❌ Archivo no encontrado: #{csv_path}"
  exit
end

# Reutilizamos myGovernors
myGovernors = Member.joins(:organization).where(organizations: { league: "CONAGO" })

# Método de similitud
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

# Identificadores requeridos
governor_role = Role.find_by(name: "Gobernador")
author_member_id = User.find_by(mail: "roberto@lantiaintelligence.com")&.member_id

if governor_role.nil? || author_member_id.nil?
  puts "❌ No se encontró el rol 'Gobernador' o el usuario con mail 'roberto@lantiaintelligence.com'"
  exit
end

creados = []
actualizados = []

CSV.foreach(csv_path, headers: true) do |row|
  firstname = row["member.firstname"].to_s.strip
  lastname1 = row["member.lastname1"].to_s.strip
  lastname2 = row["member.lastname2"].to_s.strip
  start_date = row["member.start_date"].present? ? Date.parse(row["member.start_date"]) : nil
  end_date = row["member.end_date"].present? ? Date.parse(row["member.end_date"]) : nil
  state_code = row["state.code"].to_s.strip
  state_name = row["state.name"].to_s.strip

  organization = Organization.find_by(name: "Gobierno de #{state_name}")
  if organization.nil?
    puts "⚠️ Organización no encontrada: Gobierno de #{state_name}"
    next
  end

  # Buscar duplicado
  match = myGovernors.find do |gov|
    gov.firstname == firstname && gov.lastname1 == lastname1 && gov.lastname2 == lastname2
  end

  match ||= myGovernors.find do |gov|
    members_similar?(gov, OpenStruct.new(firstname: firstname, lastname1: lastname1, lastname2: lastname2))
  end

  if match
    match.update(start_date: start_date, end_date: end_date)
    actualizados << match
  else
    new_member = Member.create!(
      firstname: firstname,
      lastname1: lastname1,
      lastname2: lastname2,
      start_date: start_date,
      end_date: end_date,
      role_id: governor_role.id,
      organization_id: organization.id,
      member_id: author_member_id
    )
    creados << new_member
  end
end

# Impresión de resultados
puts "Miembros creados: #{creados.size}"
creados.each do |m|
  puts "- [Nuevo] #{m.firstname} #{m.lastname1} #{m.lastname2} (#{m.organization&.name})"
end

puts "Miembros actualizados: #{actualizados.size}"
actualizados.each do |m|
  puts "- [Actualizado] #{m.firstname} #{m.lastname1} #{m.lastname2} (#{m.organization&.name})"
end

puts "Segunda etapa completada."

puts "Iniciando tercera etapa: procesamiento de secretarios de seguridad desde CSV"

csv_path = Rails.root.join("scripts", "Secretarios de seguridad - Plataforma.csv")
unless File.exist?(csv_path)
  puts "❌ Archivo no encontrado: #{csv_path}"
  exit
end

# Asegurar existencia del rol "Secretario de Seguridad"
chief_role = Role.find_or_create_by!(name: "Secretario de Seguridad")

# Cargar al autor del registro
author_member_id = User.find_by(mail: "roberto@lantiaintelligence.com")&.member_id
if author_member_id.nil?
  puts "❌ Usuario con mail 'roberto@lantiaintelligence.com' no encontrado"
  exit
end

# Cargar secretarios ya existentes
myChiefs = Member.joins(:role).where(roles: { name: "Secretario de Seguridad" })

creados = []
actualizados = []

CSV.foreach(csv_path, headers: true) do |row|
  firstname = row["member.firstname"].to_s.strip
  lastname1 = row["member.lastname1"].to_s.strip
  lastname2 = row["member.lastname2"].to_s.strip
  start_date = row["member.start_date"].present? ? Date.parse(row["member.start_date"]) : nil
  end_date = row["member.end_date"].present? ? Date.parse(row["member.end_date"]) : nil
  state_name = row["state.name"].to_s.strip

  organization = Organization.find_by(name: "Gobierno de #{state_name}")
  if organization.nil?
    puts "⚠️ Organización no encontrada: Gobierno de #{state_name}"
    next
  end

  # Buscar duplicado
  match = myChiefs.find do |chief|
    chief.firstname == firstname && chief.lastname1 == lastname1 && chief.lastname2 == lastname2
  end

  match ||= myChiefs.find do |chief|
    members_similar?(chief, OpenStruct.new(firstname: firstname, lastname1: lastname1, lastname2: lastname2))
  end

  if match
    match.update(start_date: start_date, end_date: end_date)
    actualizados << match
  else
    new_member = Member.create!(
      firstname: firstname,
      lastname1: lastname1,
      lastname2: lastname2,
      start_date: start_date,
      end_date: end_date,
      role_id: chief_role.id,
      organization_id: organization.id,
      member_id: author_member_id
    )
    creados << new_member
  end
end

# Imprimir resultados
puts "Miembros creados (Secretarios de Seguridad): #{creados.size}"
creados.each do |m|
  puts "- [Nuevo] #{m.firstname} #{m.lastname1} #{m.lastname2} (#{m.organization&.name})"
end

puts "Miembros actualizados (Secretarios de Seguridad): #{actualizados.size}"
actualizados.each do |m|
  puts "- [Actualizado] #{m.firstname} #{m.lastname1} #{m.lastname2} (#{m.organization&.name})"
end

puts "Tercera etapa completada."

puts "Iniciando cuarta etapa: fusión de duplicados con secretarios de seguridad"

# Paso 1: Miembros con al menos un hit
myMembers = Member.joins(:hits).distinct
puts "Miembros con hits: #{myMembers.size}"

# Paso 2: Secretarios de Seguridad (reutilizando si ya está creado)
myChiefs = Member.joins(:role).where(roles: { name: "Secretario de Seguridad" })
puts "Secretarios de Seguridad identificados: #{myChiefs.size}"

fusionados = []

ActiveRecord::Base.transaction do
  myMembers.each do |member|
    myChiefs.each do |chief|
      next if member.id == chief.id

      exact_match = member.firstname == chief.firstname &&
                    member.lastname1 == chief.lastname1 &&
                    member.lastname2 == chief.lastname2

      similar_match = !exact_match && members_similar?(member, chief)

      if exact_match || similar_match
        tipo = exact_match ? "Idéntico" : "Similar"

        # 1) Transferir atributos si existen
        chief.member_id ||= member.member_id if member.member_id.present?
        chief.media_score ||= member.media_score unless member.media_score.nil?
        chief.involved = true if member.involved

        # 2) Asignar criminal_link
        chief.criminal_link ||= member.organization_id if member.organization_id.present?

        # 3) Transferencia de hits
        member.hits.each do |hit|
          chief.hits << hit unless chief.hits.include?(hit)
        end

        chief.save!

        # 4) Eliminar al miembro original
        member_id = member.id
        member.destroy

        # 5) Imprimir resultados
        puts "Fusionado y eliminado duplicado (#{tipo}):"
        puts "- Secretario ID: #{chief.id} | #{chief.firstname} #{chief.lastname1} #{chief.lastname2} (#{chief.organization&.name})"
        puts "- Eliminado Member ID: #{member_id}"
        puts "- Hits transferidos: #{member.hits.size}"
        puts "- criminal_link asignado: #{chief.criminal_link}" if chief.criminal_link
        puts "- member_id asignado: #{chief.member_id}" if chief.member_id
        puts "- media_score: #{chief.media_score}, involved: #{chief.involved}"
        puts "-------------------------------------------------------------"

        fusionados << chief
        break # evita duplicar el mismo member con múltiples chiefs
      end
    end
  end
end

puts "Total de fusiones realizadas: #{fusionados.size}"
puts "Cuarta etapa completada."

puts "Iniciando quinta etapa: creación de hits para titulares sin cobertura"

target_states = ["Baja California", "Guerrero", "Morelos", "Michoacán", "Sinaloa", "Tamaulipas"]
fecha_corte = Date.parse("2010-01-01")

targetMembers = Member.joins(:organization)
  .where(role_id: Role.where(name: ["Gobernador", "Secretario de Seguridad"]))
  .where("members.start_date > ?", fecha_corte)
  .where("organizations.name IN (?)", target_states.map { |s| "Gobierno de #{s}" })
  .left_outer_joins(:hits)
  .group("members.id")
  .having("COUNT(hits.id) = 0")

puts "Miembros sin hits encontrados: #{targetMembers.length}"


# 2) Mapeo de códigos para generar town_id
state_codes = {
  "Baja California" => "02",
  "Guerrero" => "12",
  "Morelos" => "17",
  "Michoacán" => "16",
  "Sinaloa" => "25",
  "Tamaulipas" => "28"
}

# 3) Mapeo de organizaciones históricas pre-2020
historical_links = {
  "Guerrero" => "Guerreros Unidos",
  "Morelos" => "Los Rojos",
  "Michoacán" => "Los Caballeros Templarios",
  "Sinaloa" => "Cártel de Sinaloa",
  "Tamaulipas" => "Cártel del Golfo"
}

nuevos_hits = 0

targetMembers.each do |member|
  puts "Creando hit para ✅ "+member.firstname+" "+member.lastname1
  state = State.find_by(name: member.organization&.name&.sub("Gobierno de ", ""))
  next unless state
  code = state_codes[state.name]

  town_id = Town.find_by(full_code: "#{code}0000000").id
  unless town_id
    puts "⚠️ No se encontró town para #{state.name} con código #{code}0000000"
    next
  end

  # Crear hit

  legacy_prefix = member.start_date.strftime("%Y%m%d")
  legacy_random = SecureRandom.hex(4)  # genera 8 caracteres hex

  legacy_id = "AUTO-#{legacy_prefix}-#{legacy_random}"

  
  hit = Hit.create!(
    date: member.start_date,
    town_id: town_id,
    title: "Nombramiento/toma de protesta",
    legacy_id: legacy_id
  )

  hit.members << member
  hit.save!

  # Marcar como persona expuesta
  member.involved = false

  # Asignar criminal_link
  if member.start_date > Date.parse("2020-01-01")
    year = member.start_date.year
    org_id = Organization.joins(events: [:leads, :town => { county: :state }])
                         .where(states: { id: state.id })
                         .where("EXTRACT(YEAR FROM events.event_date) = ?", year)
                         .group("organizations.id")
                         .order("COUNT(leads.id) DESC")
                         .limit(1)
                         .pluck(:id).first
    member.criminal_link_id = org_id if org_id
  else
    org_name = historical_links[state.name]
    if org_name
      org_id = Organization.find_by(name: org_name).id

      member.criminal_link_id = org_id if org_id
    end
  end

  member.save!
  nuevos_hits += 1

  puts "✅ Hit creado para #{member.firstname} #{member.lastname1} (#{member.role&.name}, #{state.name})"
  puts "→ Involved: false, Criminal link ID: #{member.criminal_link}, Town ID: #{town_id}"
end

puts "Total de hits creados: #{nuevos_hits}"
puts "Quinta etapa completada."

