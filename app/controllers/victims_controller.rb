class VictimsController < ApplicationController

	def new_query
		helpers.clear_session
		session[:checkedYearsArr] = []
		years = helpers.get_regular_years
		session[:checkedYearsArr] = years.pluck(:id)
		states = State.all.sort_by {|state| state.code}
		session[:checkedStatesArr] = states.pluck(:id)
		cities = City.all.sort_by {|city| city.name}
		session[:checkedCitiesArr] = cities.pluck(:id)
		genderOptions = ["Masculino","Femenino","No identificado"]
		session[:checkedGenderOptions] = genderOptions
		countiesArr = []
		session[:victim_freq_params] = ["annual","stateWise","noGenderSplit", years, session[:checkedStatesArr], session[:checkedCitiesArr], genderOptions, countiesArr]
		session[:checkedCounties] = "states"
		redirect_to '/victims'
	end

	def query
		if victim_freq_params[:freq_timeframe]
			session[:victim_freq_params][0] = victim_freq_params[:freq_timeframe]
		end
		if victim_freq_params[:freq_placeframe]
			session[:victim_freq_params][1] = victim_freq_params[:freq_placeframe]
		end
		if victim_freq_params[:freq_genderframe]
			session[:victim_freq_params][2] = victim_freq_params[:freq_genderframe]
		end
		if victim_freq_params[:freq_years]
			session[:checkedYearsArr] = victim_freq_params[:freq_years].map(&:to_i)
			myArr = []
			victim_freq_params[:freq_years].each{|id|
				myArr.push(Year.find(id))
			}
			session[:victim_freq_params][3] = myArr
		end
		if victim_freq_params[:freq_states]
			session[:checkedStatesArr] = victim_freq_params[:freq_states].map(&:to_i) 
			# myArr = []
			# victim_freq_params[:freq_states].each{|id|
			# 	myArr.push(id)
			# }
			session[:victim_freq_params][4] = session[:checkedStatesArr]
		end
		if victim_freq_params[:freq_gender_options]
			session[:checkedGenderOptions] = victim_freq_params[:freq_gender_options]
			session[:victim_freq_params][6] = session[:checkedGenderOptions]
		end
		if victim_freq_params[:freq_counties]
			myArr = victim_freq_params[:freq_counties].map(&:to_i)
			Cookie.create(:data=>myArr)
			session[:checkedCounties] = Cookie.last.id
			session[:victim_freq_params][7] = session[:checkedCounties]
		else
			session[:checkedCounties] = "states"
			session[:victim_freq_params][7] = session[:checkedCounties]
		end
		session[:checkedCitiesArr] = victim_freq_params[:freq_cities]
		session[:checkedCitiesArr] = session[:checkedCitiesArr].map(&:to_i)
		session[:victim_freq_params][5] = session[:checkedCitiesArr]
		redirect_to "/victims"	
	end

	def victims
		@years = helpers.get_regular_years
		if session[:victim_freq_params][3].length < @years.length
			@my_freq_table = victim_freq_table(*session[:victim_freq_params])
		elsif session[:victim_freq_params][4].length < State.all.length
			@my_freq_table = victim_freq_table(*session[:victim_freq_params])
		elsif session[:victim_freq_params][5].length < City.all.length
			@my_freq_table = victim_freq_table(*session[:victim_freq_params])
		elsif session[:victim_freq_params][6].length < 3
			@my_freq_table = victim_freq_table(*session[:victim_freq_params])
		elsif session[:checkedCounties] != "states"
			@my_freq_table = victim_freq_table(*session[:victim_freq_params])
		else
			@my_freq_table = Cookie.where(:category=>"victims").last.data[0][session[:victim_freq_params][0]][session[:victim_freq_params][1]][session[:victim_freq_params][2]]
		end

		# FRAMES FOR ANALISYS
		@timeFrames = [
  			{caption:"Anual", box_id:"annual_query_box", name:"annual"},
			{caption:"Trimestral", box_id:"quarterly_query_box", name:"quarterly"},
			{caption:"Mensual", box_id:"monthly_query_box", name:"monthly"},
  		]
  		@placeFrames = [
  			{caption:"Nacional", box_id:"nation_query_box", name:"nationWise"},
  			{caption:"Estado", box_id:"state_query_box", name:"stateWise"},
			{caption:"Z Metro.", box_id:"city_query_box", name:"cityWise"},
			{caption:"Municipio", box_id:"county_query_box", name:"countyWise"},
  		]
  		@genderFrames = [
  			{caption:"No desagregar", box_id:"no_gender_split_query_box", name:"noGenderSplit"},
			{caption:"Desagregar", box_id:"gender_split_query_box", name:"genderSplit"},
  		]

  		if session[:victim_freq_params][0] == "annual"
  			@timeFrames[0][:checked] = true
  			@annual = true
  		elsif session[:victim_freq_params][0] == "quarterly"
  			@timeFrames[1][:checked] = true
  			@quarterly = true
  		elsif session[:victim_freq_params][0] == "monthly"
  			@timeFrames[2][:checked] = true
  		end

  		if session[:victim_freq_params][1] == "nationWise"
  			@nationWise = true
  			@placeFrames[0][:checked] = true
  		elsif session[:victim_freq_params][1] == "stateWise"
  			@stateWise = true
  			@placeFrames[1][:checked] = true
  		elsif session[:victim_freq_params][1] == "cityWise"
  			@cityWise = true
  			@placeFrames[2][:checked] = true
  		elsif session[:victim_freq_params][1] == "countyWise"
  			@countyWise = true
  			@placeFrames[3][:checked] = true
  		end

  		if session[:victim_freq_params][2] == "noGenderSplit"
  			@genderFrames[0][:checked] = true
  		elsif session[:victim_freq_params][2] == "genderSplit"
  			@genderFrames[1][:checked] = true
  		end

  		@sortCounter = 0
  		@sortType = "victims"
  		@checkedYears = session[:checkedYearsArr]
  		@states = State.all.sort
  		@cities = City.all.sort_by {|city| city.name}
  		@genderOptions = [
  			{"caption"=>"Masculino","value"=>"Masculino"},
  			{"caption"=>"Femenino","value"=>"Femenino"},
  			{"caption"=>"No identificado","value"=>"No identificado"},
  		]
  		@checkedStates = session[:checkedStatesArr]
  		@checkedCities = session[:checkedCitiesArr]
  		@checkedGenderOptions = session[:checkedGenderOptions]
  		if @checkedStates.length == 1
  			targetState = State.find(@checkedStates[0])
  			@counties = targetState.counties.sort_by {|county| county.full_code}
  		else
  			@counties = []
  		end
  		unless session[:checkedCounties] == "states"
  			@checkedCounties = Cookie.find(session[:checkedCounties]).data
  		else
  			@checkedCounties = []
  		end
  		@county_toast_message = 'Seleccione estado y municipios en "Filtros"'	
	end

	def victim_freq_table(period, scope, gender, years, states, cities, genderOptions, counties)
		myTable = []
		headerHash = {}
		totalHash = {}
		totalHash[:name] = "Total"
		
		myStates = []
		states.each {|x|
			myState = State.find(x)
			myStates.push(myState)
		}

		myCities = []
		cities.each {|x|
			myCity = City.find(x)
			myCities.push(myCity)
		}

		if	scope == "nationWise"
			myScope = nil
		elsif scope == "stateWise"
			headerHash[:scope] = "ESTADO" 
			myScope = myStates
		elsif scope == "cityWise"
			headerHash[:scope] = "Z METRO"
			myScope = myCities
		elsif scope == "countyWise"
			headerHash[:pre_scope] = "ESTADO"
			totalHash[:county_placer] = "--"
			headerHash[:scope] = "MUNICIPIO"
			myScope = []
			if counties == "states"
				myStates.each{|state|
					myScope.push(state.counties)
				}
			else
				myCounties = []
				myKeys = Cookie.find(counties).data
				myKeys.each {|x|
					myCounty = County.find(x)
					myCounties.push(myCounty)
				}
				myScope = myCounties
			end		
			myScope = myScope.flatten
			myScope = myScope.sort_by {|county| county.full_code}
			pp myScope
		end

		if period == "annual"
			myPeriod = helpers.get_specific_years(years, "victims")
		elsif period == "quarterly"
			myPeriod = helpers.get_specific_quarters(years, "victims")
		elsif period == "monthly"
			myPeriod = helpers.get_specific_months(years, "victims")
		end

		totalFreq = []
		(1..myPeriod.length).each {
			totalFreq.push(0)
		}

		headerHash[:period] = myPeriod

		if myScope == nil
			if gender == "noGenderSplit"
				myTable.push(headerHash)
				placeHash = {}
				placeHash[:name] = "Nacional"
				freq = []
				counter = 0
				place_total = 0
				myPeriod.each {|timeUnit|
					number_of_victims = timeUnit.victims.length
					freq.push(number_of_victims)
					totalFreq[counter] += number_of_victims
					counter += 1
					place_total += number_of_victims
				}
				placeHash[:freq] = freq
				placeHash[:place_total] = place_total
				myTable.push(placeHash)
			else
				headerHash[:gender] = "GÉNERO"
				totalHash[:gender_placer] = "--"
				myTable.push(headerHash)
				genderOptions.each{|gender|
					placeHash = {}
					placeHash[:name] = "Nacional"
					placeHash[:gender] = gender
					freq = []
					counter = 0
					place_total = 0
					myPeriod.each {|timeUnit|
						number_of_victims = timeUnit.victims.where(:gender=>gender).length
						freq.push(number_of_victims)
						totalFreq[counter] += number_of_victims
						counter += 1
						place_total += number_of_victims
					}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total 
					myTable.push(placeHash)
				}	
			end
		else
			if gender == "noGenderSplit"
				myTable.push(headerHash)
				myScope.each {|place|
					localVictims = place.victims
						placeHash = {}
						placeHash[:name] = place.name
						if scope == "countyWise"
							placeHash[:parent_name] = place.state.shortname
							placeHash[:full_code] = place.full_code
						end
						freq = []
						counter = 0
						place_total = 0
						
						myPeriod.each {|timeUnit|
							number_of_victims = localVictims.merge(timeUnit.victims).length
							freq.push(number_of_victims)
							totalFreq[counter] += number_of_victims
							counter += 1
							place_total += number_of_victims
						}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total
					myTable.push(placeHash)
				}
			else
				headerHash[:gender] = "GÉNERO"
				totalHash[:gender_placer] = "--"
				myTable.push(headerHash)
				myScope.each {|place|
					genderOptions.each{|gender|
						placeHash = {}
						placeHash[:name] = place.name
						if scope == "countyWise"
							placeHash[:parent_name] = place.state.shortname
							placeHash[:full_code] = place.full_code
						end
						placeHash[:gender] = gender
						freq = []
						counter = 0
						place_total = 0
						localVictims = place.victims
						myPeriod.each {|timeUnit|
							number_of_victims = timeUnit.victims.where(:gender=>gender).merge(localVictims).length
							freq.push(number_of_victims)
							totalFreq[counter] += number_of_victims
							counter += 1
							place_total += number_of_victims
						}
						placeHash[:freq] = freq
						placeHash[:place_total] = place_total 
						myTable.push(placeHash)
					}
				}
			end
		end
		totalHash[:freq] = totalFreq
		total_total = 0
		totalFreq.each{|q|
			total_total += q
		}
		totalHash[:total_total] = total_total
		myTable.push(totalHash)
		return myTable
	end

	def api
		helpers.clear_session
		session[:checkedYearsArr] = []
		years = helpers.get_regular_years
		session[:checkedYearsArr] = years.pluck(:id)
		states = State.all.sort_by {|state| state.code}
		session[:checkedStatesArr] = states.pluck(:id)
		cities = City.all.sort_by {|city| city.name}
		session[:checkedCitiesArr] = cities.pluck(:id)
		genderOptions = ["Masculino","Femenino","No identificado"]
		session[:checkedGenderOptions] = genderOptions
		data = {}
		myArr = [%w{annual quarterly monthly},%w{nationWise stateWise cityWise},%w{noGenderSplit genderSplit}]
		myArr[0].each{|timeframe|
			timeHash = {}
			myArr[1].each{|placeframe|
				placeHash = {}
				myArr[2].each{|genderframe|
					session[:victim_freq_params] = [timeframe, placeframe, genderframe, years, session[:checkedStatesArr], session[:checkedCitiesArr], genderOptions, "states"]
					placeHash[genderframe] = victim_freq_table(*session[:victim_freq_params])
				}
				timeHash[placeframe] = placeHash
			}
			data[timeframe] = timeHash
		}
		Cookie.create(:data=>[data], :category=>"victims")
		redirect_to '/victims/new_query'
	end

	def load_victims
		myFile = load_victims_params[:file]
		linkArr = []
		(1..10).map{|x| linkArr.push("Link "+x.to_s)}
        CSV.foreach(myFile, :headers => true) do |row|
        	if Killing.where(:legacy_id=>row["ID"]).length == 0
        		if Killing.where(:legacy_id=>row["No Evento"]).length == 0
        			
        			# CREATE EVENT AND ADD SOURCES
        			event = {}
        			event[:event_date] = row["Año"]+"-"+row["Mes"]+"-"+row["Día"]
        			unless row["Municipio"].nil?
        				myString = helpers.zero_padded_full_code(row["Municipio"])
        			else
        				myString = State.where(:name=>row["Estado"]).last.code + "000"	
        			end
        			unless County.where(:full_code=>myString).last.towns.where(:name=>row["Colonia o Localidad"]).empty?
        				event[:town_id] = County.where(:full_code=>myString).last.towns.where(:name=>row["Colonia o Localidad"]).last.id
        			else
        				event[:town_id] = County.where(:full_code=>myString).last.towns.where(:name=>"Sin definir").last.id
        			end
        			Event.create(event)
					myMonth = Month.where(:name=>Event.last.event_date.strftime("%Y_%m")).last.id
					Event.last.update(:month_id=>myMonth)
        			linkArr.each{|x|
        				unless row[x].nil?
			        		if Source.where(:url=>row[x]).any?
								mySource = Source.where(:url=>row[x]).last
							else
								Source.create(:url=>row[x])
								mySource = Source.last
							end
							Event.last.sources << mySource
        				end
        			}

        			# CREATE KILLING
        			killing = {}
        			killing[:event_id] = Event.last.id
					killing[:legacy_id] = row["ID"]
					killing[:killed_count] = row["Total Ejecuciones"].to_i
					killing[:arrested_count] = row["No Detenidos"].to_i
					killing[:legacy_number] = row["No Evento"]
					killing[:aggresor_count] = row["Cuántos Ejecutadores"]
					killing[:killer_vehicle_count] = row["Cuántos Vehículos Ejecutadores"]
					if row["Lugar en que fue Ejecutado_Recat"] == ""
						killing[:type_of_place] = row["Dónde se encontro Cadáver_Recat"]
					else
						killing[:type_of_place] = row["Lugar en que fue Ejecutado_Recat"]
					end
					boolean_killing_dictionary = [
						{:fire_weapon=>"Arma de Fuego"},
						{:white_weapon=>"Arma Blanca"},
						{:aggression=>"Fue Agresion"},
						{:shooting_between_criminals_and_authorities=>"Fue Enfrentamiento entre DO y Aut"},
						{:car_chase=>"Hubo Persecución"},
						{:shooting_among_criminals=>"Fue Entrentamiento entre delincuentes"}
					]
					boolean_killing_dictionary.each{|variable|
						myString = variable.values[0]
						myKey = variable.keys[0]
						if row[myString] == "VERDADERO"
							killing[myKey] = true
						else
							killing[myKey] = false
						end
					}
					Killing.create(killing)

					# CREATE VICTIMS
					create_victims(row, Killing.last.id)
				else
					create_victims(row, Killing.where(:legacy_id=>row["No Evento"]).last.id)
        		end
        	end
        end

        # SUCCESS AND REDIRECT
		session[:filename] = load_victims_params[:file].original_filename
		session[:load_success] = true
		redirect_to "/datasets/load"
	end

    def create_victims(row, killing_id)
		victim = {}
		victim[:killing_id] = killing_id
		victim[:legacy_name] = row["Nombre del Ejecutado"]
		victim[:lastname1] = row["Apellido Paterno del Ejecutado"]
		victim[:lastname2] = row["Apellido Materno del Ejecutado"]
		victim[:alias] = row["Alias del Ejecutado"]
		victim[:legacy_role_officer] = row["OE Recat"]
		victim[:legacy_role_civil] = row["Cve OCE Recat"]
		victim[:gender] = row["Género"]
		victim[:age] = row["Edad del Ejecutado"]
		if victim[:legacy_role_officer] == "Civil accidentalmente ejecutado"
			victim[:innocent_bystander] = true
		else	
			victim[:innocent_bystander] = false
		end
		(1..row["Numero de Ejecutados"].to_i).map{Victim.create(victim)}      	
    end

	private

	def victim_freq_params
		params[:query][:freq_years] ||= []
		params.require(:query).permit(:freq_timeframe, :freq_placeframe, :freq_genderframe, freq_years: [], freq_states: [], freq_cities: [], freq_counties: [], freq_gender_options: [])
	end

	def load_victims_params
		params.require(:query).permit(:file)
	end

end
