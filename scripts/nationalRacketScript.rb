puts "Working ✅"

# Cargar de forma eficiente los datos
my_counties = County.includes(:state, :rackets).to_a
my_cartels = Sector.where(scian2: 98).last.organizations.where(active: true).distinct.to_a

# Encabezados
header1 = ["MUNICIPIO"] + my_counties.map { |c| "#{c.name} - #{c.state.shortname}" }
header2 = ["CLAVE INEGI"] + my_counties.map(&:full_code)

main_arr = [header1, header2]

# Para cada cartel, construimos su fila
my_cartels.each do |cartel|
  row = [cartel.name]

  my_counties.each do |county|
    racket_ids = county.rackets.map(&:id).to_set
    row << (racket_ids.include?(cartel.id) ? 1 : 0)
  end

  main_arr << row
end

puts main_arr.inspect
puts "Ready ✅"

