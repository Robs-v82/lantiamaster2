module VictimsHelper

	def gender_keys
		keys = [
			{:name=>"Femenino", :color=>"#EF4E50"},
			{:name=>"Masculino", :color=>"#80CBCB"},
			{:name=>"Sin definir", :color=>'#E0E0E0'}
		]
		return keys	
	end

	def age_keys
		keys = [
			{:name=>"50 +", :range=>[50,100000]},
			{:name=>"40s", :range=>[40,49]},
			{:name=>"30s", :range=>[30,39]},
			{:name=>"20s", :range=>[20,29]},
			{:name=>"< 20", :range=>[0,19]}
		]
	end

	def police_keys
		keys = [
			{:name=>"SEDENA", :categories=>["Militar SEDENA"]},
			# {:name=>"SEMAR", :categories=>["Militar SEMAR"]},
			{:name=>"PF/GN", :categories=>["Guardia Nacional", "Policía Federal"]},
			{:name=>"Policía Estatal", :categories=>["Policía Estatal (caminos)", "Policía Estatal (investigación)", "Policía Estatal (procesal)", "Policía Estatal (reacción)", "Policía Estatal (auxiliar)", "Policía Estatal (custodio penitenciario)", "Policía Estatal (bancaria)", "Policía Estatal (no especificado)"]},
			{:name=>"Policía Municipal", :categories=>["Policía Municipal (preventivo)","Policía Municipal (tránsito o vial)","Policía Municipal (comunitario)","Policía Municipal (no especificado)"]},
			{:name=>"Policía (no especificado)", :categories=>["Policía No Especificado u otro"]},
			# {:name=>"FGR/Fiscalía Estatal", :categories=>[]}
		]
		return keys
	end

    def female_victims(quarter, place, localVictims)
        quarterVictims = quarter.victims
        femaleQuarterVictims = localVictims.merge(quarterVictims).where(:gender=>"FEMENINO").length
        previousYear = previousYearQuarters(quarter)
        femaleYearVictims = femaleQuarterVictims
        previousYear.each{|q|
            quarterVictims = q.victims
            thisQuarteFemaleVictims = localVictims.merge(quarterVictims).where(:gender=>"FEMENINO").length
            femaleYearVictims += thisQuarteFemaleVictims
        }
        femaleViolence = false
        if (femaleQuarterVictims/place.population.to_f)*100000 > 1
            femaleViolence = true 
        elsif (femaleYearVictims/place.population.to_f)*100000 > 7
            femaleViolence = true                     
        end
        return femaleViolence
    end

    def passenger_killings(quarter, place)
    	passengerQuarterKillings = quarter.killings.merge(place.killings).where(:type_of_place=>typeOfPlaces[3][:typeArr]).length
    	previousYear = previousYearQuarters(quarter)
    	passengerYearKillings = passengerQuarterKillings
        previousYear.each{|q|
            quarterKillings = q.killings
            thisQuartePassengerKillings = q.killings.merge(place.killings).where(:type_of_place=>typeOfPlaces[3][:typeArr]).length
            passengerYearKillings += thisQuartePassengerKillings
        }
    	passengerViolence = false
    	if passengerQuarterKillings > 0 || passengerYearKillings > 1
    		passengerViolence = true
    	end
    	return passengerViolence
    end

    def commercial_killings(quarter, place)
    	commercialQuarterKillings = quarter.killings.merge(place.killings).where(:type_of_place=>typeOfPlaces[2][:typeArr]).length
    	previousYear = previousYearQuarters(quarter)
    	commercialYearKillings = commercialQuarterKillings
        previousYear.each{|q|
            quarterKillings = q.killings
            thisQuarteCommercialKillings = q.killings.merge(place.killings).where(:type_of_place=>typeOfPlaces[2][:typeArr]).length
            commercialYearKillings += thisQuarteCommercialKillings
        }
    	commercialViolence = false
    	if (commercialQuarterKillings/place.population.to_f)*200000 > 0 || (commercialYearKillings/place.population.to_f)*200000 > 3
    		commercialViolence = true
    	end
    	return commercialViolence
    end

    def police_victims(quarter, place, localVictims)
        policeQuarterVictims = localVictims.merge(quarter.victims).where.not(:legacy_role_officer=>[nil, "Civil deliberadamente ejecutado", "Civil aparentemente involucrado con el crimen organizado", "Civil accidentalmente ejecutado", "Civil no especificado", "Interno penitenciario", "No especificado"]).length
        previousYear = previousYearQuarters(quarter)
        policeYearVictims = policeQuarterVictims
        previousYear.each{|q|
            quarterVictims = q.victims
            thisQuartePoliceVictims = q.victims.merge(place.victims).where.not(:legacy_role_officer=>[nil, "Civil deliberadamente ejecutado", "Civil aparentemente involucrado con el crimen organizado", "Civil accidentalmente ejecutado", "Civil no especificado", "Interno penitenciario", "No especificado"]).length
            policeYearVictims += thisQuartePoliceVictims
        }
        policeViolence = false
        if policeQuarterVictims/place.population.to_f*10000 > 0.01 || policeYearVictims/place.population.to_f*10000 > 0.04
            policeViolence = true
        end
        return policeViolence    
    end

    def typeOfPlaces
    	myArr = [
			{:string=>"Vía pública", :typeArr=>["Vía pública (calle, avenida, banqueta, carretera)","Transporte privado (automóvil, motocicleta, bicileta)"], :color=>"#3EBF3E"},
			{:string=>"Inmueble habitacional", :typeArr=>["Inmueble habitacional propiedad del ejecutado (dentro o fuera)","Inmueble habitacional privado"], :color=>"#2F8F8F"},
			{:string=>"Comercio", :typeArr=>["Local comercial (taller, tiendita, farmacia, tortillería)","Inmueble comercial (centro comercial, gasolinera, hotel, bar)"], :color=>"#EF4E50"},
			{:string=>"Transporte de pasajeros", :typeArr=>["Transporte público colectivo (autobús, metro, tren)","Transporte público privado (taxi, UBER, mototaxi)"], :color=>"#EF974E"}			
		]
    	return myArr
    end

end
