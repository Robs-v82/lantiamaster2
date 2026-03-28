def fix_member_relationship_genders(member_id = nil)
  feminine_map = {
    "Padre"=>"Madre",
    "Hijo"=>"Hija",
    "Abuelo"=>"Abuela",
    "Nieto"=>"Nieta",
    "Tio"=>"Tia",
    "Sobrino"=>"Sobrina",
    "Padrino"=>"Madrina",
    "Ahijado"=>"Ahijada",
    "Abogado"=>"Abogada",
    "Defendido"=>"Defendida",
    "Jefe"=>"Jefa",
    "Colaborador"=>"Colaboradora",
    "Hermano"=>"Hermana",
    "Compañero"=>"Compañera",
    "Amigo"=>"Amiga",
    "Primo"=>"Prima",
    "Conyuge"=>"Conyuge",
    "Pareja"=>"Pareja",
    "Esposo"=>"Esposa",
    "Socio"=>"Socia",
    "Allegado"=>"Allegada",
    "Compadre"=>"Comadre",
    "Cuñado"=>"Cuñada",
    "Suegro"=>"Suegra",
    "Yerno"=>"Nuera"
  }

  relationships =
    if member_id.present?
      MemberRelationship.where(member_a_id: member_id).or(MemberRelationship.where(member_b_id: member_id))
    else
      MemberRelationship.all
    end

  updated = 0

  relationships.find_each do |rel|
    next unless rel.member_a && rel.member_b

    new_role_a_gender = rel.member_a.gender == "FEMENINO" ? (feminine_map[rel.role_a] || rel.role_a) : rel.role_a
    new_role_b_gender = rel.member_b.gender == "FEMENINO" ? (feminine_map[rel.role_b] || rel.role_b) : rel.role_b

    next if rel.role_a_gender == new_role_a_gender && rel.role_b_gender == new_role_b_gender

    rel.update_columns(
      role_a_gender: new_role_a_gender,
      role_b_gender: new_role_b_gender
    )

    updated += 1
    puts "Actualizada relación #{rel.id}: #{rel.role_a_gender} / #{rel.role_b_gender} -> #{new_role_a_gender} / #{new_role_b_gender}"
  end

  puts "Total actualizadas: #{updated}"
end

fix_member_relationship_genders