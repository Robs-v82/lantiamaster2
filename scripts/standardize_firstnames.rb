# config/scripts/standardize_firstnames.rb

# Diccionario de nombres a corregir
CORRECCIONES = {
  "Jose" => "José",
  "Maria" => "María",
  "Jesus" => "Jesús",
  "Ramon" => "Ramón",
  "Martin" => "Martín",
  "Monica" => "Mónica",
  "Lucia" => "Lucía",
  "Sofia" => "Sofía",
  "Sebastian" => "Sebastián",
  "Angel" => "Ángel",
  "Oscar" => "Óscar",
  "Andres" => "Andrés",
  "Raul" => "Raúl",
  "Adan" => "Adán",
  "Tomas" => "Tomás",
  "German" => "Germán",
  "Fabian" => "Fabián",
  "Julian" => "Julián",
  "Joaquin" => "Joaquín",
  "Veronica" => "Verónica",
  "Patricia" => "Patricia",
  "Adriana" => "Adriana",
  "Damian" => "Damián"
}

Member.where.not(firstname: nil).find_each(batch_size: 500) do |member|
  original = member.firstname.dup
  corregido = original.split.map do |nombre|
    CORRECCIONES[nombre] || nombre
  end.join(" ")

  if original != corregido
    puts "Corrigiendo: '#{original}' → '#{corregido}' (ID: #{member.id})"
    member.update(firstname: corregido)
  end
end