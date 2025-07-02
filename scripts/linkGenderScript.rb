# Diccionario actualizado
FEMININE_ROLE_MAP = {
  "Padre" => "Madre",
  "Hijo" => "Hija",
  "Abuelo" => "Abuela",
  "Nieto" => "Nieta",
  "Tio" => "Tia",
  "Sobrino" => "Sobrina",
  "Padrino" => "Madrina",
  "Ahijado" => "Ahijada",
  "Abogado" => "Abogada",
  "Defendido" => "Defendida",
  "Jefe" => "Jefa",
  "Colaborador" => "Colaboradora",
  "Hermano" => "Hermana",
  "Compañero" => "Compañera",
  "Amigo" => "Amiga",
  "Primo" => "Prima",
  "Conyuge" => "Conyuge",
  "Pareja" => "Pareja",
  "Esposo" => "Esposa",
  "Socio" => "Socia",
  "Allegado" => "Allegada",
  "Compadre" => "Comadre"
}

puts "Actualizando roles con diccionario ampliado..."

actualizados = 0

MemberRelationship.find_each do |rel|
  gender_a = rel.member_a&.gender
  gender_b = rel.member_b&.gender

  rel.role_a_gender = (gender_a == "FEMENINO") ? (FEMININE_ROLE_MAP[rel.role_a] || rel.role_a) : rel.role_a
  rel.role_b_gender = (gender_b == "FEMENINO") ? (FEMININE_ROLE_MAP[rel.role_b] || rel.role_b) : rel.role_b

  if rel.changed?
    rel.save(validate: false)
    actualizados += 1
  end
end

puts "Listo. Relaciones actualizadas: #{actualizados}"


