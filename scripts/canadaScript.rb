require "pp"
typeOfPlaceArr = [
			{:string=>"Vía pública", :typeArr=>["Vía pública (calle, avenida, banqueta, carretera)","Transporte privado (automóvil, motocicleta, bicileta)"], :color=>"#3EBF3E"},
			{:string=>"Inmueble habitacional", :typeArr=>["Inmueble habitacional propiedad del ejecutado (dentro o fuera)","Inmueble habitacional privado"], :color=>"#2F8F8F"},
			{:string=>"Comercio", :typeArr=>["Local comercial (taller, tiendita, farmacia, tortillería)","Inmueble comercial (centro comercial, gasolinera, hotel, bar)"], :color=>"#EF4E50"}		
	]

myArr = []
header = ["Año","Estado","Municipio","Clave INEGI","Masacre","Enfrentamiento","Vía pública","Inmueble habitacional","Comercio","Total"]
myArr.push(header)
years = ["2018","2019","2020","2021"]
years.each{|year|
	County.all.each{|county|
		t = Year.where(:name=>year).last
		countyArr = []
		countyArr.push(year)
		countyArr.push(county.state.name)
		countyArr.push(county.name)
		countyArr.push(county.full_code)
		localKillings = county.killings.merge(t.killings)
		localVictims = county.victims.merge(t.victims)
		booleans = [
			{:string=>"massacres", :killings=>localKillings.where("killed_count > ?", 3).where(:mass_grave=>nil)},
			{:string=>"shootings_authorities", :killings=>localKillings.where(:any_shooting=>true)}					
			]

		booleans.each{|boolean|
			counter = 0
			boolean[:killings].map{|k| counter += k.victims.length}
			countyArr.push(counter/localVictims.length.to_f)
		}

		typeOfPlaceArr.each{|type|
			typeKillings = localKillings.where(:type_of_place=>type[:typeArr])
			countyArr.push(typeKillings.length/localKillings.where.not(:type_of_place=>nil).length.to_f)
		}

		countyArr.push(localVictims.length)
		myArr.push(countyArr)
	}
}

fileroot = "/Users/Bobsled/desktop/canada.csv"

CSV.open(fileroot, 'w:UTF-8', write_headers: true, headers: header) do |writer|
	myArr.each do |record|
		writer << record
	end
end

# cookie = Cookie.where(:category=>"icon").last.data

# myArr = []
# header = ["Estado"]
# myArr.push(header)

# cookie.each {|state|
# 	stateArr = []
# 	stateArr.push(state[25])
# 	myArr.push(stateArr)
# }

# pp myArr
print "Done"