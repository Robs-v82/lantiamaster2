class VictimsController < ApplicationController

	after_action :remove_email_message, only: [:victims]

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
		session[:checkedCounties] = "states"
		Cookie.create(:category=>"victim_freq_params_"+session[:user_id].to_s, :data=>["quarterly","stateWise","noGenderSplit", years, session[:checkedStatesArr], session[:checkedCitiesArr], genderOptions, countiesArr])
		redirect_to '/victims'
	end

	def query
		paramsCookie = Cookie.where(:category=>"victim_freq_params_"+session[:user_id].to_s).last.data
		if victim_freq_params[:freq_timeframe]
			paramsCookie[0] = victim_freq_params[:freq_timeframe]
		end
		if victim_freq_params[:freq_placeframe]
			paramsCookie[1] = victim_freq_params[:freq_placeframe]
		end
		if victim_freq_params[:freq_genderframe]
			paramsCookie[2] = victim_freq_params[:freq_genderframe]
		end
		if victim_freq_params[:freq_years]
			session[:checkedYearsArr] = victim_freq_params[:freq_years].map(&:to_i)
			myArr = []
			victim_freq_params[:freq_years].each{|id|
				myArr.push(Year.find(id))
			}
			paramsCookie[3] = myArr
		end
		if victim_freq_params[:freq_states]
			session[:checkedStatesArr] = victim_freq_params[:freq_states].map(&:to_i) 
			# myArr = []
			# victim_freq_params[:freq_states].each{|id|
			# 	myArr.push(id)
			# }
			paramsCookie[4] = session[:checkedStatesArr]
		end
		if victim_freq_params[:freq_gender_options]
			session[:checkedGenderOptions] = victim_freq_params[:freq_gender_options]
			paramsCookie[6] = session[:checkedGenderOptions]
		end
		if victim_freq_params[:freq_counties]
			myArr = victim_freq_params[:freq_counties].map(&:to_i)
			if myArr.length < County.find(myArr.first).state.counties.length
				Cookie.create(:data=>myArr)
				session[:checkedCounties] = Cookie.last.id
				paramsCookie[7] = session[:checkedCounties]
			else
				session[:checkedCounties] = "states"
				paramsCookie[7] = session[:checkedCounties]			
			end
		else
			session[:checkedCounties] = "states"
			paramsCookie[7] = session[:checkedCounties]
		end
		session[:checkedCitiesArr] = victim_freq_params[:freq_cities]
		session[:checkedCitiesArr] = session[:checkedCitiesArr].map(&:to_i)
		paramsCookie[5] = session[:checkedCitiesArr]
		Cookie.where(:category=>"victim_freq_params_"+session[:user_id].to_s).last.update(:data=>paramsCookie)
		redirect_to "/victims"	
	end

	def county_query
		paramsCookie = Cookie.where(:category=>"victim_freq_params_"+session[:user_id].to_s).last.data
		paramsCookie[1] = "countyWise"
		session[:checkedStatesArr] = [State.where(:code=>params[:code]).last.id]
		paramsCookie[4] = session[:checkedStatesArr]
		session[:checkedCounties] = "states"
		paramsCookie[7] = session[:checkedCounties]
		Cookie.where(:category=>"victim_freq_params_"+session[:user_id].to_s).last.update(:data=>paramsCookie)
		redirect_to '/victims'
	end

	def reset_map
		paramsCookie = Cookie.where(:category=>"victim_freq_params_"+session[:user_id].to_s).last.data
		session[:checkedStatesArr] = State.pluck(:id)
		paramsCookie[1] = "stateWise"
		session[:checkedCounties] = "states"
		paramsCookie[4] = session[:checkedStatesArr]
		Cookie.where(:category=>"victim_freq_params_"+session[:user_id].to_s).last.update(:data=>paramsCookie)
		redirect_to '/victims'
	end

	def victims
		@paramsCookie = Cookie.where(:category=>"victim_freq_params_"+session[:user_id].to_s).last.data
		@chartDisplay = true
		@user = User.find(session[:user_id])
		@victims = true
		@maps = true
		@years = helpers.get_regular_years
		session[:years] = @years
		@checkedStates = session[:checkedStatesArr]

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

  		if @paramsCookie[0] == "annual"
  			@timeFrames[0][:checked] = true
  			@annual = true
  		elsif @paramsCookie[0] == "quarterly"
  			@timeFrames[1][:checked] = true
  			@quarterly = true
  		elsif @paramsCookie[0] == "monthly"
  			@timeFrames[2][:checked] = true
  		end

  		if @paramsCookie[1] == "nationWise"
  			@maps = false
  			@nationWise = true
  			@placeFrames[0][:checked] = true
  		elsif @paramsCookie[1] == "stateWise"
  			@stateWise = true
  			@placeFrames[1][:checked] = true
  		elsif @paramsCookie[1] == "cityWise"
  			@cityWise = true
  			@placeFrames[2][:checked] = true
  		elsif @paramsCookie[1] == "countyWise"
  			@countyWise = true
  			@placeFrames[3][:checked] = true
  			@stateCode = State.find(session[:checkedStatesArr].last).code
  		end

  		if @paramsCookie[2] == "noGenderSplit"
  			@genderFrames[0][:checked] = true
  		elsif @paramsCookie[2] == "genderSplit"
  			@maps = false
  			@genderFrames[1][:checked] = true
  		end

		if @paramsCookie[2] == "genderSplit" ||
			@paramsCookie[3].length < @years.length ||
			@paramsCookie[4].length < State.all.length && @paramsCookie[4].length > 1 ||
			@paramsCookie[4].length == 1 && @stateWise ||
			@paramsCookie[5].length < City.all.length ||
			@paramsCookie[6].length < 3 ||
			session[:checkedCounties] != "states"
				@maps = false
				@my_freq_table = victim_freq_table(*@paramsCookie)
		elsif @countyWise && session[:checkedCounties] == "states"
			@my_freq_table = Cookie.where(:category=>State.find(@checkedStates.last).code+"_victims").last.data[0][@paramsCookie[0]][@paramsCookie[2]]
				@maps = true
		else
			@my_freq_table = Cookie.where(:category=>"victims").last.data[0][@paramsCookie[0]][@paramsCookie[1]][@paramsCookie[2]]
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
  		factor = 1
  		if @countyWise
  			factor = 0.05
  		end
  		@dataClasses = [
  			factor*200*@checkedYears.length,
  			factor*500*@checkedYears.length,
  			factor*1000*@checkedYears.length
  		]
  		@pieStrings = %w{massacres shootings_authorities mass_graves} 

  		@fileHash = {:data=>@my_freq_table,:formats=>['csv']}
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
					myScope.push(state.counties.select{|county| county.victims.any?})
				}
			else
				myCounties = []
				myKeys = Cookie.find(counties).data
				myKeys.each {|x|
					myCounty = County.find(x)
					if myCounty.victims.any?	
						myCounties.push(myCounty)
					end
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
		genderKeys = helpers.gender_keys
		ageKeys = helpers.age_keys
		policeKeys = helpers.police_keys

		typeOfPlaceArr = [
			{:string=>"Vía pública", :typeArr=>["Vía pública (calle, avenida, banqueta, carretera)","Transporte privado (automóvil, motocicleta, bicileta)"], :color=>"#3EBF3E"},
			{:string=>"Inmueble habitacional", :typeArr=>["Inmueble habitacional propiedad del ejecutado (dentro o fuera)","Inmueble habitacional privado"], :color=>"#2F8F8F"},
			{:string=>"Comercio", :typeArr=>["Local comercial (taller, tiendita, farmacia, tortillería)","Inmueble comercial (centro comercial, gasolinera, hotel, bar)"], :color=>"#EF4E50"},
			{:string=>"Transporte público", :typeArr=>["Transporte público colectivo (autobús, metro, tren)","Transporte público privado (taxi, UBER, mototaxi)"], :color=>"#EF974E"}			
		]

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

			# MAP DATA
			if gender == "noGenderSplit"
				myTable.push(headerHash)
				if scope == "stateWise" || scope == "cityWise" 
					myScope.push("Nacional")
				elsif scope == "countyWise" && states.length == 1
					myScope.push("Estado")
				end
				myScope.each {|place|
					if place == "Nacional"
						placeName = "Nacional"
						placeCode = "00"
						localVictims = Victim.all
						localKillings = Killing.all
					elsif place == "Estado"
						placeName = State.find(states.last).name
						placeCode = "000"
						localVictims = State.find(states.last).victims
						localKillings = State.find(states.last).killings
					else
						placeName = place.name
						placeCode = place.code
						localVictims = place.victims
						localKillings = place.killings
					end
					placeHash = {}
					placeHash[:name] = placeName
					placeHash[:code] = placeCode
					if scope == "countyWise"
						if place == "Estado"
							placeHash[:parent_name] = placeName
							placeHash[:full_code] = "00000"	
						else
							placeHash[:parent_name] = place.state.shortname
							placeHash[:full_code] = place.full_code
						end
					end
					freq = []
					counter = 0
					place_total = 0
					myPeriod.each {|timeUnit|
						number_of_victims = localVictims.merge(timeUnit.victims).length
						freq.push(number_of_victims)
						unless place == "Nacional" || place =="Estado"
							totalFreq[counter] += number_of_victims
						end
						counter += 1
						place_total += number_of_victims	
					}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total

					# GENDER
					genderArr = []
					genderKeys.each{|k|
						if k[:name] == "Femenino" || k[:name] == "Masculino"
							genderHash = {:name=>k[:name], :color=>k[:color]}
							genderHash[:freq] = localVictims.where(:gender=>k[:name].upcase).length
							genderHash[:share] = genderHash[:freq]/localVictims.where(:gender=>["MASCULINO","FEMENINO"]).length.to_f
							genderArr.push(genderHash)
						end
					}
					placeHash[:genders] = genderArr

					# AGE
					ageArr = []
					ageKeys.each{|k|
						ageHash = {:name=>k[:name]}
						number_of_victims = localVictims.where('age >= ?', k[:range][0])
						number_of_victims = number_of_victims.where('age <= ?', k[:range][1]).length
						ageHash[:freq] = number_of_victims
						ageHash[:share] = number_of_victims/localVictims.where.not(:age=>nil).length.to_f
						ageArr.push(ageHash)
					}
					placeHash[:ages] = ageArr

					# POLICE
					policeArr = []
					policeKeys.each{|k|
						policeHash = {:name=>k[:name]}
						policeHash[:freq] = localVictims.where(:legacy_role_officer=>k[:categories]).length
						policeArr.push(policeHash)
					}
					placeHash[:agencies] = policeArr

					# BOOLEANS
					booleans = [
						{:string=>"massacres", :killings=>localKillings.where("killed_count > ?", 3).where(:mass_grave=>nil)},
						{:string=>"mass_graves", :killings=>localKillings.where(:mass_grave=>true)},
						{:string=>"shootings_authorities", :killings=>localKillings.where(:any_shooting=>true)}					
					]
					booleans.each{|boolean|
						counter = 0
						boolean[:killings].map{|k| counter += k.victims.length}
						placeHash[boolean[:string]] = {:freq=>boolean[:killings].length, :share=>counter/localVictims.length.to_f}	
					}

					# TYPE OF PLACE
					types = []
					typeCounter = 0
					typeOfPlaceArr.each{|type|
						typeHash = {:name=>type[:string]}
						typeKillings = localKillings.where(:type_of_place=>type[:typeArr])
						typeHash[:color] = type[:color]
						typeHash[:freq] = typeKillings.length
						typeHash[:share] = typeHash[:freq]/localKillings.where.not(:type_of_place=>nil).length.to_f
						types.push(typeHash)
						typeCounter += typeHash[:share]
					}
					nilTypeHash = {
						:name=>"Otro",
						:color=>'#e0e0e0',
						:share=> 1 - typeCounter,
					}
					types.push(nilTypeHash)
					placeHash[:types] = types

					myTable.push(placeHash)
				}
				# END OF MAP DATA

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
						localVictims = place.victims.where(:gender=>gender.upcase)
						myPeriod.each {|timeUnit|
							number_of_victims = timeUnit.victims.merge(localVictims).length
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

	def load_victims
		myFile = load_victims_params[:file]
		if load_victims_params[:month].empty?
			months = Year.where(:name=>load_victims_params[:year]).last.months
			validDate = load_victims_params[:year]
		else
			myString = load_victims_params[:year] + "_" + load_victims_params[:month] 
			months = Month.where(:name=>myString).last
			validDate = load_victims_params[:year] + "-" + load_victims_params[:month]
		end
		linkArr = []
		(1..10).map{|x| linkArr.push("Link "+x.to_s)}
		boolean_killing_dictionary = [
			{:fire_weapon=>"Arma de Fuego"},
			{:white_weapon=>"Arma Blanca"},
			{:aggression=>"Fue Agresion"},
			{:shooting_between_criminals_and_authorities=>"Fue Enfrentamiento entre DO y Aut"},
			{:car_chase=>"Hubo Persecución"},
			{:shooting_among_criminals=>"Fue Entrentamiento entre delincuentes"},
			{:shooting=>"Fue Enfrentamiento"}
		]
		# monthArr = []
        CSV.foreach(myFile, :headers => true) do |row|
        	dateString = row["Año"]+"-"+row["Mes"]+"-"+row["Día"]
        	if dateString.include? validDate
	        	if Killing.where(:legacy_id=>row["ID"], :legacy_number=>row["No Evento"]).empty?
	        		paddedMonth = row["Mes"].to_i
	        		paddedMonth = paddedMonth + 100
	        		paddedMonth = paddedMonth.to_s[1,2]
	        		monthString = row["Año"]+"_"+paddedMonth
	        		myMonth = Month.where(:name=>monthString).last
	        		if row["Estado"] == "Distrito Federal"
	        			myState = State.where(:name=>"Ciudad de México").last
	        		else
	        			myState = State.where(:name=>row["Estado"]).last
	        		end
	    			if row["Municipio"].nil?
	    				myString = myState.code + "0000000"
	    				myCounty = myState.counties.where(:name=>"Sin definir").last
	    			else
	    				myString = helpers.zero_padded_full_code(row["Municipio"]) + "0000"
	    				myCounty = County.where(:full_code=>myString[0,5]).last
	    			end
	        		if myCounty.killings.where(:legacy_number=>row["No Evento"]).merge(myMonth.killings.where(:legacy_number=>row["No Evento"])).empty?
	        			# CREATE EVENT AND ADD SOURCES
	        			event = {}
	        			event[:event_date] = dateString
	        			event[:town_id] = Town.where(:full_code=>myString).last.id
	        			Event.create(event)
						myMonth = Month.where(:name=>Event.last.event_date.strftime("%Y_%m")).last
						# monthArr.push(myMonth)
						# monthArr.uniq!
						Event.last.update(:month_id=>myMonth.id)

	       #  			linkArr.each{|x|
	       #  				unless row[x].nil?
				    #     		if Source.where(:url=>row[x]).any?
								# 	mySource = Source.where(:url=>row[x]).last
								# else
								# 	Source.create(:url=>row[x])
								# 	mySource = Source.last
								# end
								# Event.last.sources << mySource
	       #  				end
	       #  			}

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

						boolean_killing_dictionary.each{|variable|
							myString = variable.values[0]
							myKey = variable.keys[0]
							if row[myString] == "VERDADERO" || row[myString] == "Sí"
								killing[myKey] = true
							else
								killing[myKey] = false
							end
						}
						if row["Dónde se encontro Cadáver_Recat"] == "Narcofosa o fosa clandestina"
							killing[:mass_grave] = true
						end
						Killing.create(killing)

						# CREATE VICTIMS
						create_victims(row, Killing.last.id)
					else
						create_victims(row, myCounty.killings.where(:legacy_number=>row["No Evento"]).last.id)
	        		end
	        	end
	        end
        end

		Killing.all.each{|killing|
			if killing.shooting
				killing.update(:any_shooting=>true)
			elsif killing.shooting_between_criminals_and_authorities
				killing.update(:any_shooting=>true)
			elsif killing.shooting_among_criminals
				killing.update(:any_shooting=>true)
			end
		}

        # SUCCESS AND REDIRECT
		session[:filename] = load_victims_params[:file].original_filename
		session[:load_success] = true
		api(months)
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
		if row["Género"]
			victim[:gender] = row["Género"].upcase
		end
		victim[:age] = row["Edad del Ejecutado"]
		if victim[:legacy_role_officer] == "Civil accidentalmente ejecutado"
			victim[:innocent_bystander] = true
		else	
			victim[:innocent_bystander] = false
		end
		(1..row["Total Ejecuciones"].to_i).map{Victim.create(victim)}      	
    end

	def send_file
		paramsCookie = Cookie.where(:category=>"victim_freq_params_"+session[:user_id].to_s).last.data
		recipient = User.find(session[:user_id])
		current_date = Date.today.strftime
		if paramsCookie[2] == "genderSplit" || paramsCookie[3].length < session[:years].length || paramsCookie[4].length < State.all.length && paramsCookie[4].length > 1 || paramsCookie[5].length < City.all.length || paramsCookie[6].length < 3 || session[:checkedCounties] != "states"
			records = victim_freq_table(*paramsCookie)
		elsif paramsCookie[1] == "countyWise" && session[:checkedCounties] == "states"
			records = Cookie.where(:category=>State.find(session[:checkedStatesArr].last).code+"_victims").last.data[0][paramsCookie[0]][paramsCookie[2]]
		else
			records = Cookie.where(:category=>"victims").last.data[0][paramsCookie[0]][paramsCookie[1]][paramsCookie[2]]
		end
	 	file_name = "victimas("+current_date+")."
	 	caption = "víctimas"
		file_root = Rails.root.join("private",file_name)
		myLength = helpers.root_path[:myLength]
		QueryMailer.freq_email(recipient, file_root, file_name, records, myLength, caption, params[:timeframe], paramsCookie[1], params[:extension]).deliver_now
		session[:email_success] = true
		redirect_to "/victims"		
	end

	def api(months)
		helpers.clear_session
		checkedYearsArr = []
		years = helpers.get_regular_years
		checkedYearsArr = years.pluck(:id)
		states = State.all.sort_by {|state| state.code}
		checkedStatesArr = states.pluck(:id)
		cities = City.all.sort_by {|city| city.name}
		checkedCitiesArr = cities.pluck(:id)
		genderOptions = ["Masculino","Femenino","No identificado"]
		checkedGenderOptions = genderOptions
		
		# CREATE API FOR EACH STATE
		data = {}
		myArr = [%w{annual quarterly monthly}, %w{noGenderSplit genderSplit}]
		State.all.each{|state|
			if Cookie.where(:category=>state.code+"_victims").any?
				myCookie = Cookie.where(:category=>state.code+"_victims").last
				oldData = myCookie.data[0]
			end
			stateHash = {}
			myArr[0].each{|timeframe|
				timeHash = {}
				myArr[1].each{|genderframe|
					stateParams = [timeframe, "countyWise", genderframe, years, [state.id], checkedCitiesArr, genderOptions, "states", months]
					timeHash[genderframe] = api_freq_table(*stateParams)
					print (state.name+"*******")*200
					if oldData
						oldData[timeframe][genderframe][0][:period].append(*timeHash[genderframe][0][:period])
						t = oldData[timeframe][genderframe].length 
						(1..t-2).each{|x|
							print oldData[timeframe][genderframe][x][:freq]
							print timeHash[genderframe][x][:freq] 
							oldData[timeframe][genderframe][x][:freq].append(*timeHash[genderframe][x][:freq])
							[:genders, :ages, :agencies, "massacres", "mass_graves", "shootings_authorities", :types].each{|mySymbol|
								oldData[timeframe][genderframe][x][mySymbol] =	timeHash[genderframe][x][mySymbol]
							}
							oldData[timeframe][genderframe][x][:place_total] += timeHash[genderframe][x][:place_total]
						}
						oldData[timeframe][genderframe][-1][:freq].append(*timeHash[genderframe][-1][:freq])
						totalCounter = 0
						oldData[timeframe][genderframe][-1][:freq].map{|f| totalCounter += f}
						oldData[timeframe][genderframe][-1][:total_total] = totalCounter
					end 
				}
				stateHash[timeframe] = timeHash
			}
			data = stateHash
			if myCookie
				myCookie.update(:data=>[oldData])
			else
				Cookie.create(:data=>[data], :category=>state.code+"_victims")
			end
		}

		# CREATE NATIONAL API
		data = {}
		myArr = [%w{annual quarterly monthly}, %w{nationWise stateWise cityWise}, %w{noGenderSplit genderSplit}]
		if Cookie.where(:category=>"victims").any?
			myNationalCookie = Cookie.where(:category=>"victims").last
			oldNationalData = myNationalCookie.data[0]
		end
		myArr[0].each{|timeframe|
			timeHash = {}
			myArr[1].each{|placeframe|
				placeHash = {}
				myArr[2].each{|genderframe|
					victim_freq_params = [timeframe, placeframe, genderframe, years, checkedStatesArr, checkedCitiesArr, genderOptions, "states", months]
					placeHash[genderframe] = api_freq_table(*victim_freq_params)
					if oldNationalData
						oldNationalData[timeframe][placeframe][genderframe][0][:period].append(*placeHash[genderframe][0][:period])
						t = oldNationalData[timeframe][placeframe][genderframe].length
						(1..t-2).each{|x|
							oldNationalData[timeframe][placeframe][genderframe][x][:freq].append(*placeHash[genderframe][x][:freq])
							[:genders, :ages, :agencies, "massacres", "mass_graves", "shootings_authorities", :types].each{|mySymbol|
								oldNationalData[timeframe][placeframe][genderframe][x][mySymbol] =	placeHash[genderframe][x][mySymbol]
							}
							oldNationalData[timeframe][placeframe][genderframe][x][:place_total] += placeHash[genderframe][x][:place_total]
						}
						oldNationalData[timeframe][placeframe][genderframe][-1][:freq].append(*placeHash[genderframe][-1][:freq])
						totalCounter = 0
						oldNationalData[timeframe][placeframe][genderframe][-1][:freq].map{|f| totalCounter += f}
						oldNationalData[timeframe][placeframe][genderframe][-1][:total_total] = totalCounter
					end 
				}
				timeHash[placeframe] = placeHash
			}
			data[timeframe] = timeHash
		}
		if myNationalCookie
			myNationalCookie.update(:data=>[oldNationalData])
		else
			Cookie.create(:data=>[data], :category=>"victims")
		end
	end

	def api_freq_table(period, scope, gender, years, states, cities, genderOptions, counties, months)
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
			if counties == "states"
				myScope = [myStates.first.counties]
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
			myPeriod = []
			months.map{|month| myPeriod.push(month.quarter.year); myPeriod.uniq!}
		elsif period == "quarterly"
			myPeriod = []
			months.map{|month| myPeriod.push(month.quarter); myPeriod.uniq!}
		elsif period == "monthly"
			myPeriod = []
			months.map{|month| myPeriod.push(month); myPeriod.uniq!}
		end

		totalFreq = []
		(1..myPeriod.length).each {
			totalFreq.push(0)
		}

		headerHash[:period] = myPeriod
		genderKeys = helpers.gender_keys
		ageKeys = helpers.age_keys
		policeKeys = helpers.police_keys

		typeOfPlaceArr = [
			{:string=>"Vía pública", :typeArr=>["Vía pública (calle, avenida, banqueta, carretera)","Transporte privado (automóvil, motocicleta, bicileta)"], :color=>"#3EBF3E"},
			{:string=>"Inmueble habitacional", :typeArr=>["Inmueble habitacional propiedad del ejecutado (dentro o fuera)","Inmueble habitacional privado"], :color=>"#2F8F8F"},
			{:string=>"Comercio", :typeArr=>["Local comercial (taller, tiendita, farmacia, tortillería)","Inmueble comercial (centro comercial, gasolinera, hotel, bar)"], :color=>"#EF4E50"},
			{:string=>"Transporte público", :typeArr=>["Transporte público colectivo (autobús, metro, tren)","Transporte público privado (taxi, UBER, mototaxi)"], :color=>"#EF974E"}			
		]

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

			# MAP DATA
			if gender == "noGenderSplit"
				myTable.push(headerHash)
				if scope == "stateWise" || scope == "cityWise" 
					myScope.push("Nacional")
				elsif scope == "countyWise" && states.length == 1
					myScope.push("Estado")
				end
				myScope.each {|place|
					if place == "Nacional"
						placeName = "Nacional"
						placeCode = "00"
						localVictims = Victim.all
						localKillings = Killing.all
					elsif place == "Estado"
						placeName = State.find(states.last).name
						placeCode = "000"
						localVictims = State.find(states.last).victims
						localKillings = State.find(states.last).killings
					else
						placeName = place.name
						placeCode = place.code
						localVictims = place.victims
						localKillings = place.killings
					end
					placeHash = {}
					placeHash[:name] = placeName
					placeHash[:code] = placeCode
					if scope == "countyWise"
						if place == "Estado"
							placeHash[:parent_name] = placeName
							placeHash[:full_code] = "00000"	
						else
							placeHash[:parent_name] = place.state.shortname
							placeHash[:full_code] = place.full_code
						end
					end
					freq = []
					counter = 0
					place_total = 0
					myPeriod.each {|timeUnit|
						number_of_victims = localVictims.merge(timeUnit.victims).length
						freq.push(number_of_victims)
						unless place == "Nacional" || place =="Estado"
							totalFreq[counter] += number_of_victims
						end
						counter += 1
						place_total += number_of_victims	
					}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total

					# GENDER
					genderArr = []
					genderKeys.each{|k|
						if k[:name] == "Femenino" || k[:name] == "Masculino"
							genderHash = {:name=>k[:name], :color=>k[:color]}
							genderHash[:freq] = localVictims.where(:gender=>k[:name].upcase).length
							genderHash[:share] = genderHash[:freq]/localVictims.where(:gender=>["MASCULINO","FEMENINO"]).length.to_f
							genderArr.push(genderHash)
						end
					}
					placeHash[:genders] = genderArr

					# AGE
					ageArr = []
					ageKeys.each{|k|
						ageHash = {:name=>k[:name]}
						number_of_victims = localVictims.where('age >= ?', k[:range][0])
						number_of_victims = number_of_victims.where('age <= ?', k[:range][1]).length
						ageHash[:freq] = number_of_victims
						ageHash[:share] = number_of_victims/localVictims.where.not(:age=>nil).length.to_f
						ageArr.push(ageHash)
					}
					placeHash[:ages] = ageArr

					# POLICE
					policeArr = []
					policeKeys.each{|k|
						policeHash = {:name=>k[:name]}
						policeHash[:freq] = localVictims.where(:legacy_role_officer=>k[:categories]).length
						policeArr.push(policeHash)
					}
					placeHash[:agencies] = policeArr

					# BOOLEANS
					booleans = [
						{:string=>"massacres", :killings=>localKillings.where("killed_count > ?", 3).where(:mass_grave=>nil)},
						{:string=>"mass_graves", :killings=>localKillings.where(:mass_grave=>true)},
						{:string=>"shootings_authorities", :killings=>localKillings.where(:any_shooting=>true)}					
					]
					booleans.each{|boolean|
						counter = 0
						boolean[:killings].map{|k| counter += k.victims.length}
						placeHash[boolean[:string]] = {:freq=>boolean[:killings].length, :share=>counter/localVictims.length.to_f}	
					}

					# TYPE OF PLACE
					types = []
					typeCounter = 0
					typeOfPlaceArr.each{|type|
						typeHash = {:name=>type[:string]}
						typeKillings = localKillings.where(:type_of_place=>type[:typeArr])
						typeHash[:color] = type[:color]
						typeHash[:freq] = typeKillings.length
						typeHash[:share] = typeHash[:freq]/localKillings.where.not(:type_of_place=>nil).length.to_f
						types.push(typeHash)
						typeCounter += typeHash[:share]
					}
					nilTypeHash = {
						:name=>"Otro",
						:color=>'#e0e0e0',
						:share=> 1 - typeCounter,
					}
					types.push(nilTypeHash)
					placeHash[:types] = types

					myTable.push(placeHash)
				}
				# END OF MAP DATA

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

	private

	def victim_freq_params
		params[:query][:freq_years] ||= []
		params.require(:query).permit(:freq_timeframe, :freq_placeframe, :freq_genderframe, freq_years: [], freq_states: [], freq_cities: [], freq_counties: [], freq_gender_options: [])
	end

	def load_victims_params
		params.require(:query).permit(:file, :year, :month)
	end

end
