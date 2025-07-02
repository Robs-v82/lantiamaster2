# Diccionario de transformaciones al femenino
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
  "Colaborador" => "Colaboradora"
}

puts "Corrigiendo valores de role_a_gender y role_b_gender..."

actualizados = 0

MemberRelationship.find_each do |rel|
  # Géneros de los miembros
  gender_a = rel.member_a&.gender
  gender_b = rel.member_b&.gender

  # Aplicar transformación si el género es FEMENINO
  rel.role_a_gender = (gender_a == "FEMENINO") ? (FEMININE_ROLE_MAP[rel.role_a] || rel.role_a) : rel.role_a
  rel.role_b_gender = (gender_b == "FEMENINO") ? (FEMININE_ROLE_MAP[rel.role_b] || rel.role_b) : rel.role_b

  if rel.changed?
    rel.save(validate: false)
    actualizados += 1
  end
end

puts "¡Actualización completa! Relaciones modificadas: #{actualizados}"

