# scripts/cleanFalseMembers.rb

# Asegúrate de que este script se ejecuta en el contexto de Rails
# y que el modelo Member está cargado.

# Define la variable targetMembers
targetMembers = Member.joins(:hits).distinct

# Inicializa un contador para llevar el total de eliminados
deleted_count = 0

# Itera sobre cada miembro en targetMembers
targetMembers.find_each do |member|
  # Obtiene lastname1 y lastname2, manejando posibles valores nulos
  ln1 = member.lastname1.to_s.strip
  ln2 = member.lastname2.to_s.strip

  should_delete = false

  # Verifica la primera condición: longitud <= 1
  if ln1.length <= 1 || ln2.length <= 1
    should_delete = true
  end

  # Verifica la segunda condición: longitud <= 2 y contiene un punto
  if (ln1.length <= 2 && ln1.include?('.')) || (ln2.length <= 2 && ln2.include?('.'))
    should_delete = true
  end

  if should_delete
    puts "Eliminando miembro ID: #{member.id}, Nombre: #{member.firstname}, Apellido1: #{ln1}, Apellido2: #{ln2}"
    member.destroy
    deleted_count += 1
  end
end

puts "\nTotal de miembros eliminados: #{deleted_count}"
