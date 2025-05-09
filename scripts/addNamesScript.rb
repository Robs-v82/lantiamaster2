require 'securerandom'

# Función para comparar nombres
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

# Paso 1: detainees con nombre completo y organización
valid_detainees = Member.where.not(firstname: nil, lastname1: nil, lastname2: nil)
                        .where("LENGTH(firstname) >= 3")
                        .where("LENGTH(lastname1) >= 3")
                        .where("LENGTH(lastname2) >= 3")
                        .where.not(organization_id: nil)
                        .where.not(detention_id: nil)

# Paso 2: miembros con al menos un hit asociado
key_members = Member.joins(:hits).distinct.to_a

# Paso 3 y 4: agrupar detainees por evento, verificar similitud y crear hits
grouped_detainees = valid_detainees.includes(detention: :event).group_by { |m| m.detention.event }

# Acumulador global de miembros agregados
all_added_members = []

grouped_detainees.each do |event, detainees|
  next unless event && event.event_date && event.town_id

  new_hit_members = []

  detainees.each do |detainee|
    exists = key_members.any? { |existing| members_similar?(existing, detainee) }
    unless exists
      new_hit_members << detainee
      all_added_members << detainee
    end
  end

  next if new_hit_members.empty?

  # Crear el nuevo hit
  hit = Hit.create!(
    date: event.event_date,
    town_id: event.town_id,
    legacy_id: "event_#{event.id}_#{SecureRandom.hex(4)}"
  )

  # Asociar los nuevos miembros al hit
  hit.members << new_hit_members
  puts "✅ Hit creado (ID: #{hit.id}) con #{new_hit_members.size} nuevos miembros asociados al evento ##{event.id}"
end

# Imprimir resultados
puts "\n📋 Miembros agregados a nuevos hits:"
all_added_members.each do |member|
  puts "- #{member.id} #{member.firstname} #{member.lastname1} #{member.lastname2}"
end

puts "\n🔢 Total de nuevos miembros asociados a hits: #{all_added_members.size}"
