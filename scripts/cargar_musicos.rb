require 'csv'
require 'i18n'

# Asegurar que I18n esté configurado
I18n.config.available_locales = :es

file_path = Rails.root.join('scripts', 'Músicos - Plataforma.csv')
author_member_id = User.find_by(mail: "roberto@lantiaintelligence.com")&.member_id
role_id = Role.find_by(name: "Servicios lícitos")&.id

# Función para comparación de miembros
def members_similar?(m1, m2)
  fn1 = I18n.transliterate(m1.firstname.to_s.downcase)
  ln1a = I18n.transliterate(m1.lastname1.to_s.downcase)
  ln1b = I18n.transliterate(m1.lastname2.to_s.downcase)

  fn2 = I18n.transliterate(m2.firstname.to_s.downcase)
  ln2a = I18n.transliterate(m2.lastname1.to_s.downcase)
  ln2b = I18n.transliterate(m2.lastname2.to_s.downcase)

  firstname_match = fn1.include?(fn2) || fn2.include?(fn1)
  lastname1_match = ln1a.include?(ln2a) || ln2a.include?(ln1a)
  lastname2_match = ln1b.include?(ln2b) || ln2b.include?(ln1b)

  firstname_match && lastname1_match && lastname2_match
end

identicos = []
actualizados = []
nuevos = []

CSV.foreach(file_path, headers: true) do |row|
  next if row['organization.name'].blank?

  firstname  = row['member.firstname'].to_s.strip
  lastname1  = row['member.lastname1'].to_s.strip
  lastname2  = row['member.lastname2'].to_s.strip
  org_name   = row['organization.name'].to_s.strip
  organization = Organization.find_or_create_by!(name: org_name)
  criminal_link_name = row['member.criminal_link'].to_s.strip
  criminal_link = Organization.find_by_name(criminal_link_name).id
  hit = Hit.find_by_legacy_id(row['hit.legacy_id'].to_s.strip)

  temp_member = Member.new(firstname: firstname, lastname1: lastname1, lastname2: lastname2)
  match_candidates = Member.where.not(firstname: [nil, ''], lastname1: [nil, ''], lastname2: [nil, ''])
  match = match_candidates.find { |m| members_similar?(m, temp_member) }

  if match
    original_org_id = match.organization_id
    if Organization.find(original_org_id) == organization 
      match.update!(:criminal_link_id=>criminal_link)
      identicos << match  
    else
      match.update!(
        organization_id: organization.id,
        criminal_link_id: original_org_id
      )
      actualizados << match
    end
    if match.hits.empty?
      match.hits << hit
    end
  else
    nuevo = Member.create!(
      firstname: firstname,
      lastname1: lastname1,
      lastname2: lastname2,
      organization_id: organization.id,
      criminal_link_id: criminal_link,
      involved: false,
      member_id: author_member_id,
      role_id: role_id
    )
    nuevo.hits << hit
    nuevos << nuevo
  end
end

puts "Resumen de carga de músicos"
puts "---------------------------"
puts "Miembros identicos: #{identicos.count}"
identicos.each { |m| puts "- #{m.firstname} #{m.lastname1} #{m.lastname2}" }
puts "Miembros actualizados: #{actualizados.count}"
actualizados.each { |m| puts "- #{m.firstname} #{m.lastname1} #{m.lastname2}" }

puts "\nMiembros creados: #{nuevos.count}"
nuevos.each { |m| puts "- #{m.firstname} #{m.lastname1} #{m.lastname2}" }
