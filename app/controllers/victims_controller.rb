class VictimsController < ApplicationController

	after_action :remove_email_message, only: [:victims]
	before_action :require_pro, only: [:query, :county_query]
	before_action :require_victim_access, only: [:victims]

	def new_query
		helpers.clear_session
		session[:checkedYearsArr] = []
		years = helpers.get_regular_years
		session[:checkedYearsArr] = years.pluck(:id)
		if session[:membership] < 2
			states = helpers.demo_states
		else
			states = State.all.sort_by {|state| state.code}	
		end
		session[:checkedStatesArr] = states.pluck(:id)
		cities = City.all.sort_by {|city| city.name}
		session[:checkedCitiesArr] = cities.pluck(:id)
		genderOptions = ["Masculino","Femenino","No identificado"]
		session[:checkedGenderOptions] = genderOptions
		countiesArr = []
		session[:checkedCounties] = "states"
		if session[:membership] == 3
			timeframe = "monthly"
		else
			timeframe = "quarterly"
		end
		Cookie.create(:category=>"victim_freq_params_"+session[:user_id].to_s, :data=>[timeframe,"stateWise","noGenderSplit", years, session[:checkedStatesArr], session[:checkedCitiesArr], genderOptions, countiesArr])
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
			validCounties = Cookie.where(:category=>State.find(session[:checkedStatesArr].last).code+"_victims").last.data[0][paramsCookie[0]]["noGenderSplit"].count - 3
			if myArr.count < validCounties
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
		@user = User.find(session[:user_id])
		@victims = true
		@maps = false
		if session[:membership] < 2
			@maps = true
		end
		@years = helpers.get_regular_years
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

  		# DEFINE TABLE
		if @paramsCookie[2] == "genderSplit" || @paramsCookie[1] == "nationWise"
			@my_freq_table = victim_freq_table(*@paramsCookie)
		elsif @stateWise && @paramsCookie[4].count < State.all.count || 
			@paramsCookie[5].count < City.all.count ||
			session[:checkedCounties] != "states"			
			@my_freq_table = partial_table
		elsif @countyWise && session[:checkedCounties] == "states"
			thisState = State.find(@checkedStates.last)
			@my_freq_table = Cookie.where(:category=>thisState.code+"_victims").last.data[0][@paramsCookie[0]][@paramsCookie[2]]
			freqArr = Cookie.where(:category=>thisState.code+"_victims").last.data[0][@paramsCookie[0]][@paramsCookie[2]][-2][:freq]
			freqTotal = Cookie.where(:category=>thisState.code+"_victims").last.data[0][@paramsCookie[0]][@paramsCookie[2]][-2][:place_total]
			remainder = {
				:name=>"Otros*",
				:parent_name=>thisState.shortname,
				:freq=>freqArr,
				:place_total=>freqTotal
			}
			@my_freq_table[1..-3].each{|row|
				(0..@my_freq_table[-1][:freq].count-1).each {|x|
					remainder[:freq][x] -= row[:freq][x] 
				}
				remainder[:place_total] -= row[:place_total]
			}
			@my_freq_table.insert(-2, remainder)
			@my_freq_table[-1][:freq] = Cookie.where(:category=>thisState.code+"_victims").last.data[0][@paramsCookie[0]][@paramsCookie[2]][-2][:freq] 
			@my_freq_table[-1][:total_total] = Cookie.where(:category=>thisState.code+"_victims").last.data[0][@paramsCookie[0]][@paramsCookie[2]][-2][:place_total] 
			@maps = true
		else
			@my_freq_table = Cookie.where(:category=>"victims").last.data[0][@paramsCookie[0]][@paramsCookie[1]][@paramsCookie[2]]
			@maps = true
		end

		if session[:membership] < 2
			@my_freq_table.insert(-2, Cookie.where(:category=>"victims").last.data[0][@paramsCookie[0]][@paramsCookie[1]][@paramsCookie[2]][-2])
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
  		if @checkedStates.count == 1
  			targetState = State.find(@checkedStates[0])
  			@counties = []
  			counties = targetState.counties.sort_by {|county| county.full_code}
  			counties.map{|c| 
  				if c.victims.count > 4
  					@counties.push(c)
  				end
  			}
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
  			factor*200*@checkedYears.count,
  			factor*500*@checkedYears.count,
  			factor*1000*@checkedYears.count
  		]
  		@pieStrings = %w{massacres shootings_authorities mass_graves} 

  		@fileHash = {:data=>@my_freq_table,:formats=>['csv']}
	end

	def partial_table
		paramsCookie = Cookie.where(:category=>"victim_freq_params_"+session[:user_id].to_s).last.data
		if paramsCookie[1] == "countyWise"
			table = Cookie.where(:category=>State.find(session[:checkedStatesArr].last).code+"_victims").last.data[0][paramsCookie[0]][paramsCookie[2]]
		else
			table = Cookie.where(:category=>"victims").last.data[0][paramsCookie[0]][paramsCookie[1]][paramsCookie[2]]
		end
		if paramsCookie[1] == "stateWise"
			partialHash = {:model=>State, :keys=>paramsCookie[4]}
		elsif paramsCookie[1] == "cityWise"
			partialHash = {:model=>City, :keys=>paramsCookie[5]}
		else
			data = Cookie.find(paramsCookie[7]).data
			partialHash = {:model=>County, :keys=>data}
		end
		codeArr = []
		partialHash[:keys].each{|key|
			code = partialHash[:model].find(key).code
			codeArr.push(code)
		}
		newTable = [table[0]]
		table[1..-2].map{|row| if codeArr.include? row[:code]; newTable.push(row); end }
		totalHash = {}
		totalHash[:name] = "Total"
		if paramsCookie[1] == "countyWise"
			totalHash[:county_placer] = "--"
		end

		totalMonths = helpers.get_specific_months(paramsCookie[3], "victims")
		if paramsCookie[0] == "annual"
			myPeriod = helpers.get_specific_years(paramsCookie[3], "victims")
			n = 12
		elsif paramsCookie[0] == "quarterly"
			myPeriod = helpers.get_specific_quarters(paramsCookie[3], "victims")
			n = 3
		elsif paramsCookie[0] == "monthly"
			myPeriod = totalMonths
			n = 1
		end
		if myPeriod.count > 1
			unless (totalMonths.count%n) == 0
				myPeriod.pop
			end
		end

		totalFreq = []
		(1..myPeriod.count).each {
			totalFreq.push(0)
		}
		newTable[1..-1].each{|row|
			(0..myPeriod.count-1).each {|x|
				totalFreq[x] += row[:freq][x] 
			}
		}

		totalHash[:freq] = totalFreq
		total_total = 0
		totalFreq.each{|q|
			total_total += q
		}
		totalHash[:total_total] = total_total
		newTable.push(totalHash)
		return newTable
	end

	def victim_freq_table(period, scope, gender, years, states, cities, genderOptions, counties)
		myTable = []
		headerHash = {}
		totalHash = {}
		totalHash[:name] = "Total"
		otherCounties = false
		
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
					myCounties = state.counties.reject { |county| county.victims.count < 5 }
					myScope.push(myCounties)
				}
			else
				myCounties = []
				myKeys = Cookie.find(counties).data
				myKeys.each {|x|
					myCounty = County.find(x)
					# if myCounty.victims.count > 4
						myCounties.push(myCounty)
					# end
				}
				myScope = myCounties
			end		
			myScope = myScope.flatten
			myScope = myScope.sort_by {|county| county.full_code}
		end

		totalMonths = helpers.get_specific_months(years, "victims")

		if period == "annual"
			myPeriod = helpers.get_specific_years(years, "victims")
			n = 12
		elsif period == "quarterly"
			myPeriod = helpers.get_specific_quarters(years, "victims")
			n = 3
		elsif period == "monthly"
			myPeriod = totalMonths
			n = 1
		end
		if myPeriod.count > 1
			unless (totalMonths.count%n) == 0
				myPeriod.pop
			end
		end

		totalFreq = []
		(1..myPeriod.count).each {
			totalFreq.push(0)
		}

		headerHash[:period] = myPeriod
		genderKeys = helpers.gender_keys
		ageKeys = helpers.age_keys
		policeKeys = helpers.police_keys

		typeOfPlaceArr = helpers.typeOfPlaces

		if myScope == nil
			if gender == "noGenderSplit"
				myTable.push(headerHash)
				placeHash = {}
				placeHash[:name] = "Nacional"
				freq = []
				counter = 0
				place_total = 0
				myPeriod.each {|timeUnit|
					number_of_victims = timeUnit.victims.count
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
						number_of_victims = timeUnit.victims.where(:gender=>gender.upcase).count
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
				# MAP DATA
				myTable.push(headerHash)
				if scope == "stateWise" || scope == "cityWise" 
					myScope.push("Nacional")
				elsif scope == "countyWise" && states.count == 1
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
						number_of_victims = localVictims.merge(timeUnit.victims).count
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
							genderHash[:freq] = localVictims.where(:gender=>k[:name].upcase).count
							genderHash[:share] = genderHash[:freq]/localVictims.where(:gender=>["MASCULINO","FEMENINO"]).count.to_f
							genderArr.push(genderHash)
						end
					}
					placeHash[:genders] = genderArr

					# AGE
					ageArr = []
					ageKeys.each{|k|
						ageHash = {:name=>k[:name]}
						number_of_victims = localVictims.where('age >= ?', k[:range][0])
						number_of_victims = number_of_victims.where('age <= ?', k[:range][1]).count
						ageHash[:freq] = number_of_victims
						ageHash[:share] = number_of_victims/localVictims.where.not(:age=>nil).count.to_f
						ageArr.push(ageHash)
					}
					placeHash[:ages] = ageArr

					# POLICE
					policeArr = []
					policeKeys.each{|k|
						policeHash = {:name=>k[:name]}
						policeHash[:freq] = localVictims.where(:legacy_role_officer=>k[:categories]).count
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
						boolean[:killings].map{|k| counter += k.victims.count}
						placeHash[boolean[:string]] = {:freq=>boolean[:killings].count, :share=>counter/localVictims.count.to_f}	
					}

					# TYPE OF PLACE
					types = []
					typeCounter = 0
					typeOfPlaceArr.each{|type|
						typeHash = {:name=>type[:string]}
						typeKillings = localKillings.where(:type_of_place=>type[:typeArr])
						typeHash[:color] = type[:color]
						typeHash[:freq] = typeKillings.count
						typeHash[:share] = typeHash[:freq]/localKillings.where.not(:type_of_place=>nil).count.to_f
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
							number_of_victims = timeUnit.victims.merge(localVictims).count
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
			months = Year.where(:name=>load_victims_params[:year]).last.months.sort
			validDate = load_victims_params[:year]
		else
			myString = load_victims_params[:year] + "_" + load_victims_params[:month] 
			months = [Month.where(:name=>myString).last]
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
        	paddedMonth = row["Mes"].to_i
	        paddedMonth = paddedMonth + 100
	        paddedMonth = paddedMonth.to_s[1,2]
        	dateString = row["Año"]+"-"+paddedMonth+"-"+row["Día"]
        	if dateString.include? validDate
	        	if Killing.where(:legacy_id=>row["ID"], :legacy_number=>row["No Evento"]).empty?
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
	    			if row["No Evento"]
	    				legacyString = row["No Evento"]+myString[0,5]+row["Año"]+paddedMonth+row["Día"]	
	    			else
	    				legacyString = "1234"+myString[0,5]+row["Año"]+paddedMonth+row["Día"]
	    			end
	        		if Killing.where(:legacy_number=>legacyString)
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
						killing[:legacy_number] = legacyString
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
							if row[myString] == "TRUE" || row[myString] == "Sí"
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
						create_victims(row, Killing.where(:legacy_number=>row["No Evento"]).last.id)
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

		Victim.all.each{|v| 
			unless v.gender == "MASCULINO" || v.gender == "FEMENINO"
			 v.update(:gender=>"NO IDENTIFICADO") 
			end
		}

        # SUCCESS AND REDIRECT

		# api(months)
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
		years = helpers.get_regular_years
		paramsCookie = Cookie.where(:category=>"victim_freq_params_"+session[:user_id].to_s).last.data
		recipient = User.find(session[:user_id])
		current_date = Date.today.strftime

		# DEFINE TABLE
		if paramsCookie[2] == "genderSplit" || paramsCookie[1] == "nationWise"
			records = victim_freq_table(*paramsCookie)
		elsif paramsCookie[1] == "stateWise" && paramsCookie[4].count < State.all.count || 
			paramsCookie[5].count < City.all.count ||
			session[:checkedCounties] != "states"			
			records = partial_table
		elsif paramsCookie[1] == "countyWise" && session[:checkedCounties] == "states"
			thisState = State.find(session[:checkedStatesArr].last)
			records = Cookie.where(:category=>thisState.code+"_victims").last.data[0][paramsCookie[0]][paramsCookie[2]]
			records = Cookie.where(:category=>thisState.code+"_victims").last.data[0][paramsCookie[0]][paramsCookie[2]]
			freqArr = Cookie.where(:category=>thisState.code+"_victims").last.data[0][paramsCookie[0]][paramsCookie[2]][-2][:freq]
			freqTotal = Cookie.where(:category=>thisState.code+"_victims").last.data[0][paramsCookie[0]][paramsCookie[2]][-2][:place_total]
			remainder = {
				:name=>"Otros",
				:parent_name=>thisState.shortname,
				:freq=>freqArr,
				:place_total=>freqTotal
			}
			records[1..-3].each{|row|
				(0..records[-1][:freq].count-1).each {|x|
					remainder[:freq][x] -= row[:freq][x] 
				}
				remainder[:place_total] -= row[:place_total]
			}
			records.insert(-2, remainder)
			records[-1][:freq] = Cookie.where(:category=>thisState.code+"_victims").last.data[0][paramsCookie[0]][paramsCookie[2]][-2][:freq] 
			records[-1][:total_total] = Cookie.where(:category=>thisState.code+"_victims").last.data[0][paramsCookie[0]][paramsCookie[2]][-2][:place_total] 
		else
			records = Cookie.where(:category=>"victims").last.data[0][paramsCookie[0]][paramsCookie[1]][paramsCookie[2]]
		end

		downloadCounter = recipient.downloads
		downloadCounter += 1
		recipient.update(:downloads=>downloadCounter)

		# OTHER FILE PARAMS
	 	file_name = "victimas_"+downloadCounter.to_s+"_"+current_date+".csv"
	 	caption = "víctimas"
		file_root = Rails.root.join("private",file_name)
		myLength = helpers.root_path[:myLength]
		
		myFile = helpers.send_freq_file(recipient, file_root, file_name, records, myLength, caption, params[:timeframe], paramsCookie[1], params[:extension])

		respond_to do |format|
			format.html
			format.csv { send_data myFile, filename: file_name}
		end

		# SHIFT TO EMAIL DELIVERY
		# QueryMailer.freq_email(recipient, file_root, file_name, records, myLength, caption, params[:timeframe], paramsCookie[1], params[:extension]).deliver_now
		# session[:email_success] = true
	end

	# def api(months)
	def states_api
		months = helpers.get_regular_months.sort
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
		myArr = [%w{annual quarterly monthly}, %w{noGenderSplit}]
		State.all.each{|state|
			stateHash = {}
			myArr[0].each{|timeframe|
				timeHash = {}
				myArr[1].each{|genderframe|
					stateParams = [timeframe, "countyWise", genderframe, years, [state.id], checkedCitiesArr, genderOptions, "states", months]
					timeHash[genderframe] = api_freq_table(*stateParams)
				}
				stateHash[timeframe] = timeHash
			}
			data = stateHash

			Cookie.create(:data=>[data], :category=>state.code+"_victims")
		}
		redirect_to '/victims/new_query'
	end

	def national_api
		months = helpers.get_regular_months.sort
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
		
		# CREATE NATIONAL API
		data = {}
		myArr = [%w{annual quarterly monthly}, %w{stateWise cityWise}, %w{noGenderSplit}]
		myArr[0].each{|timeframe|
			timeHash = {}
			myArr[1].each{|placeframe|
				placeHash = {}
				myArr[2].each{|genderframe|
					victim_freq_params = [timeframe, placeframe, genderframe, years, checkedStatesArr, checkedCitiesArr, genderOptions, "states", months]
					placeHash[genderframe] = api_freq_table(*victim_freq_params)
				}
				timeHash[placeframe] = placeHash
			}
			data[timeframe] = timeHash
		}

		Cookie.create(:data=>[data], :category=>"victims")
		redirect_to '/victims/new_query'
	end

	def national_inputs
		months = helpers.get_regular_months.sort
		helpers.clear_session
		years = helpers.get_regular_years
		checkedYearsArr = years.pluck(:id)
		states = State.all.sort_by {|state| state.code}
		checkedStatesArr = states.pluck(:id)
		cities = City.all.sort_by {|city| city.name}
		checkedCitiesArr = cities.pluck(:id)
		genderOptions = ["Masculino","Femenino","No identificado"]
		victim_freq_params = [params[:timeframe], params[:placeframe], "noGenderSplit", years, checkedStatesArr, checkedCitiesArr, genderOptions, "states", months]
		data = api_freq_table(*victim_freq_params)
		Cookie.create(:data=>[data], :category=>"victims_"+params[:timeframe]+"_"+params[:placeframe])
		redirect_to '/victims/new_query'
	end

	def national_joint

		data = {}
		myArr = [%w{annual quarterly monthly}, %w{stateWise cityWise}, %w{noGenderSplit}]
		myArr[0].each{|timeframe|
			timeHash = {}
			myArr[1].each{|placeframe|
				placeHash = {}
				myArr[2].each{|genderframe|
					myCategory = "victims_"+timeframe+"_"+placeframe
					placeHash[genderframe] = Cookie.where(:category=>myCategory).last.data[0]
				}
				timeHash[placeframe] = placeHash
			}
			data[timeframe] = timeHash
		}
		Cookie.create(:data=>[data], :category=>"victims")
		redirect_to '/victims/new_query'
	end

	def test
		months = helpers.get_regular_months.sort
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
		
		# CREATE NATIONAL API
		data = {}
		myArr = [%w{annual}, %w{stateWise}, %w{noGenderSplit}]
		myArr[0].each{|timeframe|
			timeHash = {}
			myArr[1].each{|placeframe|
				placeHash = {}
				myArr[2].each{|genderframe|
					victim_freq_params = [timeframe, placeframe, genderframe, years, checkedStatesArr, checkedCitiesArr, genderOptions, "states", months]
					placeHash[genderframe] = api_freq_table(*victim_freq_params)
				}
				timeHash[placeframe] = placeHash
			}
			data[timeframe] = timeHash
		}

		Cookie.create(:data=>[data], :category=>"test")
		redirect_to '/victims/new_query'
	end


	def national_annual_state
		months = helpers.get_regular_months.sort
		years = helpers.get_regular_years
		states = State.all.sort_by {|state| state.code}
		checkedStatesArr = states.pluck(:id)
		cities = City.all.sort_by {|city| city.name}
		checkedCitiesArr = cities.pluck(:id)
		genderOptions = ["Masculino","Femenino","No identificado"]
		current_month = "none"
		Month.all.each{|month|
			if month.victims.count != 0
				current_month = month.name
			end
		}
		victim_freq_params = ["annual", "stateWise", "noGenderSplit", years, checkedStatesArr, checkedCitiesArr, genderOptions, "states", months]
		content = api_freq_table(*victim_freq_params)
		data = [{:month=>current_month, :content=>content}]
		Cookie.create(:category=>"national_annual_state", :data=>data)
		redirect_to '/victims/new_query'
	end

	def national_annual_city
		months = helpers.get_regular_months.sort
		years = helpers.get_regular_years
		states = State.all.sort_by {|state| state.code}
		checkedStatesArr = states.pluck(:id)
		cities = City.all.sort_by {|city| city.name}
		checkedCitiesArr = cities.pluck(:id)
		genderOptions = ["Masculino","Femenino","No identificado"]
		current_month = "none"
		Month.all.each{|month|
			if month.victims.count != 0
				current_month = month.name
			end
		}
		victim_freq_params = ["annual", "cityWise", "noGenderSplit", years, checkedStatesArr, checkedCitiesArr, genderOptions, "states", months]
		content = api_freq_table(*victim_freq_params)
		data = [{:month=>current_month, :content=>content}]
		Cookie.create(:category=>"national_annual_city", :data=>data)
		redirect_to '/victims/new_query'
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

		if scope == "stateWise"
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
				myCounties = myStates.first.counties.reject { |county| county.victims.count < 5 }
				myScope = [myCounties]
			else
				myCounties = []
				myKeys = Cookie.find(counties).data
				myKeys.each {|x|
					myCounty = County.find(x)
					if myCounty.victims.count > 4
						myCounties.push(myCounty)
					end
				}
				myScope = myCounties
			end		
			myScope = myScope.flatten
			myScope = myScope.sort_by {|county| county.full_code}
		end

		totalMonths = helpers.get_specific_months(years, "victims")

		if period == "annual"
			myPeriod = helpers.get_specific_years(years, "victims")
			n = 12
		elsif period == "quarterly"
			myPeriod = helpers.get_specific_quarters(years, "victims")
			n = 3
		elsif period == "monthly"
			myPeriod = totalMonths
			n = 1
		end
		if myPeriod.count > 1
			unless (totalMonths.count%n) == 0
				myPeriod.pop
			end
		end

		totalFreq = []
		(1..myPeriod.count).each {
			totalFreq.push(0)
		}

		headerHash[:period] = myPeriod
		genderKeys = helpers.gender_keys
		ageKeys = helpers.age_keys
		policeKeys = helpers.police_keys
		# policeKeys = helpers.law_enforcement_keys
		typeOfPlaceArr = helpers.typeOfPlaces
		# typeOfPlaceArr = helpers.type_of_place_keys

		# MAP DATA
		myTable.push(headerHash)
		if scope == "stateWise" || scope == "cityWise" 
			myScope.push("Nacional")
		elsif scope == "countyWise" && states.count == 1
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
				number_of_victims = localVictims.merge(timeUnit.victims).count
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
					genderHash[:freq] = localVictims.where(:gender=>k[:name].upcase).count
					genderHash[:share] = genderHash[:freq]/localVictims.where(:gender=>["MASCULINO","FEMENINO"]).count.to_f
					genderHash[:share] = genderHash[:share].round(3)
					genderArr.push(genderHash)
				end
			}
			placeHash[:genders] = genderArr

			# AGE
			ageArr = []
			ageKeys.each{|k|
				ageHash = {:name=>k[:name]}
				number_of_victims = localVictims.where('age >= ?', k[:range][0])
				number_of_victims = number_of_victims.where('age <= ?', k[:range][1]).count
				ageHash[:freq] = number_of_victims
				ageHash[:share] = number_of_victims/localVictims.where.not(:age=>nil).count.to_f
				ageHash[:share] = ageHash[:share].round(3)
				ageArr.push(ageHash)
			}
			placeHash[:ages] = ageArr

			# POLICE
			policeArr = []
			policeKeys.each{|k|
				policeHash = {:name=>k[:name]}
				policeHash[:freq] = localVictims.where(:legacy_role_officer=>k[:categories]).count
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
				boolean[:killings].map{|k| counter += k.victims.count}
				booleanShare = counter/localVictims.count.to_f
				booleanShare = booleanShare.round(3)
				placeHash[boolean[:string]] = {:freq=>boolean[:killings].count, :share=>booleanShare}

			}

			# TYPE OF PLACE
			types = []
			typeCounter = 0
			typeOfPlaceArr.each{|type|
				typeHash = {:name=>type[:string]}
				typeKillings = localKillings.where(:type_of_place=>type[:typeArr])
				typeHash[:color] = type[:color]
				typeHash[:freq] = typeKillings.count
				typeHash[:share] = typeHash[:freq]/localKillings.where.not(:type_of_place=>nil).count.to_f
				typeHash[:share] = typeHash[:share].round(3)
				types.push(typeHash)
				typeCounter += typeHash[:share]
			}
			nilTypeHash = {
				:name=>"Otro",
				:color=>'#e0e0e0',
				:share=> 1 - typeCounter,
			}
			nilTypeHash[:share] = nilTypeHash[:share].round(3)
			types.push(nilTypeHash)
			placeHash[:types] = types

			myTable.push(placeHash)
		}

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