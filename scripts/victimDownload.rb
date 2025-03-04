require 'pp'
myQuarters = Quarter.joins(:year).where(years: { name: ["2022", "2023", "2024"] })
myQuarters = myQuarters.sort_by(&:name)

typeOfPlaces = [
	{:string=>"Vía pública", :typeArr=>["Vía pública (calle, avenida, banqueta, carretera)","Transporte privado (automóvil, motocicleta, bicileta)"], :color=>"#3EBF3E"},
	{:string=>"Inmueble habitacional", :typeArr=>["Inmueble habitacional propiedad del ejecutado (dentro o fuera)","Inmueble habitacional privado"], :color=>"#2F8F8F"},
	{:string=>"Comercio", :typeArr=>["Local comercial (taller, tiendita, farmacia, tortillería)","Inmueble comercial (centro comercial, gasolinera, hotel, bar)"], :color=>"#EF4E50"},
	{:string=>"Transporte de pasajeros", :typeArr=>["Transporte público colectivo (autobús, metro, tren)","Transporte público privado (taxi, UBER, mototaxi)"], :color=>"#EF974E"}			
]
quarterNames = myQuarters.pluck(:name)
myStates = State.all.sort_by{|s| s.code}

booleans = [
	{:string=>"massacres", :killings=>Killing.where("killed_count > ?", 3).where(:mass_grave=>nil)},
	{:string=>"mass_graves", :killings=>Killing.where(:mass_grave=>true)},
	{:string=>"shootings_authorities", :killings=>Killing.where(:any_shooting=>true)}					
]

booleans.each{|boolean|
	mainArr = [["Estado","Tipo de víctima"] + quarterNames]
	myStates.each{|state|
		stateArr = [state.name,boolean[:string]]
		localVictims = state.victims
		localKillings = boolean[:killings].merge(state.killings)	
		myQuarters.each{|q|
			periodKillings = q.killings
			targetKillings = localKillings.merge(periodKillings)
			counter = targetKillings.joins(:victims).count
			stateArr.push(counter)
		}
		mainArr.push(stateArr)
		mainArr.push([state.name,"Total"])
		myQuarters.each{|q|
			periodVictims = q.victims
			targetVictims = localVictims.merge(periodVictims)
			mainArr[-1].push(targetVictims.count)
		}
	}
	pp mainArr
}


# mainArr = [["Estado", "Tipo de lugar"] + quarterNames]
# myStates.each{|state|
# 	localVictims = state.victims
# 	localKillings = state.killings
# 	typeOfPlaces.each{|type|
# 		stateArr = [state.name]
# 		stateArr.push(type[:string])
# 		typeKillings = localKillings.where(:type_of_place=>type[:typeArr])
# 		myQuarters.each{|q|
# 			periodKillings = q.killings
# 			targetKillings = typeKillings.merge(periodKillings)
# 			counter = targetKillings.joins(:victims).count
# 			stateArr.push(counter)
# 		}
# 		mainArr.push(stateArr)
# 	}
# 	mainArr.push([state.name,"Total"])
# 	myQuarters.each{|q|
# 		periodVictims = q.victims
# 		targetVictims = localVictims.merge(periodVictims)
# 		mainArr[-1].push(targetVictims.count)
# 	}
# }