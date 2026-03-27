
def create_bulk_relationships(role_a, target_id, hit_id)
  target = Member.find(target_id)
  source_members = Hit.find(hit_id).members

  reciprocal_map = {
    "Padre"=>"Hijo","Madre"=>"Hijo",
    "Hijo"=>"Padre","Hija"=>"Padre",
    "Abuelo"=>"Nieto","Abuela"=>"Nieto",
    "Nieto"=>"Abuelo","Nieta"=>"Abuelo",
    "Tio"=>"Sobrino","Tia"=>"Sobrino",
    "Sobrino"=>"Tio","Sobrina"=>"Tio",
    "Padrino"=>"Ahijado","Madrina"=>"Ahijado",
    "Ahijado"=>"Padrino","Ahijada"=>"Padrino",
    "Abogado"=>"Defendido","Defendida"=>"Abogado",
    "Defendido"=>"Abogado",
    "Jefe"=>"Colaborador","Jefa"=>"Colaborador",
    "Colaborador"=>"Jefe","Colaboradora"=>"Jefe",
    "Hermano"=>"Hermano","Hermana"=>"Hermano",
    "Compañero"=>"Compañero","Compañera"=>"Compañero",
    "Amigo"=>"Amigo","Amiga"=>"Amigo",
    "Primo"=>"Primo","Prima"=>"Primo",
    "Conyuge"=>"Conyuge",
    "Pareja"=>"Pareja",
    "Esposo"=>"Esposa","Esposa"=>"Esposo",
    "Socio"=>"Socio","Socia"=>"Socio",
    "Allegado"=>"Allegado",
    "Compadre"=>"Compadre","Comadre"=>"Compadre",
    "Cuñado"=>"Cuñado","Cuñada"=>"Cuñado",
    "Suegro"=>"Yerno","Suegra"=>"Yerno",
    "Yerno"=>"Suegro","Nuera"=>"Suegro"
  }

  feminine_map = {
    "Padre"=>"Madre","Hijo"=>"Hija","Abuelo"=>"Abuela","Nieto"=>"Nieta",
    "Tio"=>"Tia","Sobrino"=>"Sobrina","Padrino"=>"Madrina","Ahijado"=>"Ahijada",
    "Abogado"=>"Abogada","Defendido"=>"Defendida","Jefe"=>"Jefa",
    "Colaborador"=>"Colaboradora","Hermano"=>"Hermana","Compañero"=>"Compañera",
    "Amigo"=>"Amiga","Primo"=>"Prima","Esposo"=>"Esposa","Socio"=>"Socia",
    "Allegado"=>"Allegada","Compadre"=>"Comadre","Cuñado"=>"Cuñada",
    "Suegro"=>"Suegra","Yerno"=>"Nuera"
  }

  source_members.each do |m|
    next if m.id == target.id

    role_b = reciprocal_map[role_a] || role_a

    existe = MemberRelationship.exists?(member_a_id: m.id, member_b_id: target.id, role_a: role_a, role_b: role_b) ||
             MemberRelationship.exists?(member_a_id: target.id, member_b_id: m.id, role_a: role_b, role_b: role_a)

    next if existe

    role_a_gender = m.gender == "FEMENINO" ? (feminine_map[role_a] || role_a) : role_a
    role_b_gender = target.gender == "FEMENINO" ? (feminine_map[role_b] || role_b) : role_b

    MemberRelationship.create!(
      member_a: m,
      member_b: target,
      role_a: role_a,
      role_b: role_b,
      role_a_gender: role_a_gender,
      role_b_gender: role_b_gender
    )
  end

  puts "Relaciones creadas correctamente"
end