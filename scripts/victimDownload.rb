require 'pp'
myQuarters = Quarter.joins(:year).where(years: { name: ["2022", "2023", "2024"] })

typeOfPlaces = [
	{:string=>"Vía pública", :typeArr=>["Vía pública (calle, avenida, banqueta, carretera)","Transporte privado (automóvil, motocicleta, bicileta)"], :color=>"#3EBF3E"},
	{:string=>"Inmueble habitacional", :typeArr=>["Inmueble habitacional propiedad del ejecutado (dentro o fuera)","Inmueble habitacional privado"], :color=>"#2F8F8F"},
	{:string=>"Comercio", :typeArr=>["Local comercial (taller, tiendita, farmacia, tortillería)","Inmueble comercial (centro comercial, gasolinera, hotel, bar)"], :color=>"#EF4E50"},
	{:string=>"Transporte de pasajeros", :typeArr=>["Transporte público colectivo (autobús, metro, tren)","Transporte público privado (taxi, UBER, mototaxi)"], :color=>"#EF974E"}			
]

mainArr = [["Estado","Tipo de lugar"]]
myQuarters.each{|q|
	mainArr[0].push(q.name)
	myStates = State.all.sort_by{|s| s.code}
	myStates.each{|state|
		localVictims = state.victims
		periodVictims = q.victims
		targetVictims = localVictims.merge(periodVictims)
		localKillings = state.killings
		periodKillings = q.killings
		targetKillings = localKillings.merge(periodKillings)
		typeOfPlaces.each{|type|
			stateArr = [state.name]
			stateArr.push(type[:string])
			counter = 0
			typeKillings = targetKillings.where(:type_of_place=>type[:typeArr])
			typeKillings.each{|k|
				counter += k.victims.count
			}
			stateArr.push(counter)
			mainArr.push(stateArr)
		}
		mainArr.push([state.name,"Total",targetVictims.count])
	}
}

pp mainArr