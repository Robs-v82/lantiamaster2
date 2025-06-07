require 'csv'

# Ruta al archivo CSV
file_path = Rails.root.join('scripts', 'names_by_gender.csv')

# Cargar nombres con género conocido
name_gender_map = {}

CSV.foreach(file_path, headers: true) do |row|
  name = row['firstname']&.strip&.downcase
  gender = row['genero_estimado']&.strip&.downcase

  case gender
  when 'masculino'
    name_gender_map[name] = 'MASCULINO'
  when 'femenino'
    name_gender_map[name] = 'FEMENINO'
  end
end

puts "Asignando género a miembros sin género definido…"

# Buscar y actualizar Members sin género
updated_count = 0
Member.where(gender: nil).find_each(batch_size: 500) do |member|
  key = member.firstname&.strip&.downcase
  genero = name_gender_map[key]

  next unless genero # Solo si está en el diccionario

  member.update(gender: genero)
  updated_count += 1
  puts "✓ ID #{member.id} – #{member.firstname} → #{genero}"
end

puts "Actualización completa. Total actualizados: #{updated_count}"
