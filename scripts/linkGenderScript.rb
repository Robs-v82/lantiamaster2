# Diccionario de versiones femeninas de los roles
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

puts "Iniciando actualización de género en relaciones..."

actualizados = 0

MemberRelationship.find_each do |rel|
  # Obtiene género del miembro A y B
  gender_a = rel.member_a&.gender
  gender_b = rel.member_b&.gender

  # Asigna "FEMENINO" solo si coincide exactamente
  rel.role_a_gender = (gender_a == "FEMENINO") ? "FEMENINO" : "MASCULINO"
  rel.role_b_gender = (gender_b == "FEMENINO") ? "FEMENINO" : "MASCULINO"

  # Guarda sin validación para evitar fricciones con datos heredados
  if rel.changed?
    rel.save(validate: false)
    actualizados += 1
  end
end

puts "Proceso completo. Relaciones actualizadas: #{actualizados}"
