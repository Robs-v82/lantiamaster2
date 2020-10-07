class DatasetsController < ApplicationController
	
	require 'csv'
	require 'pp'
	after_action :remove_load_message, only: [:load]

	def show
	end

	def load
		@quarters = Quarter.all.sort
		@months = Month.all.sort
		ensuLoaded = []
		violenceReportLoaded = []
		crimeVictimReportLoaded = []
		@quarters.each{|quarter|
			if quarter.ensu.attached?
				ensuLoaded.push(quarter.name)
			end
		}
		@months.each{|month|
			if month.violence_report.attached?
				violenceReportLoaded.push(month.name)
			end
			if month.crime_victim_report.attached?
				crimeVictimReportLoaded.push(month.name)
			end
		}
		@cartels = helpers.get_cartels
		if session[:load_success]
			@load_success = true
		end
		if session[:filename]
			@filename = session[:filename]
		end
		@myYears = (2010..2030)
		@forms = [
			{caption:"Perfil OC", myAction:"/organizations/load_organizations", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Referencias-Incidentes OC", myAction:"/organizations/load_organization_events", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Presencia estatal-municipal OC", myAction:"/organizations/load_organization_territory", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Detenciones", myAction:"/members/detentions", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"ENSU BP1_1", myAction:"/datasets/load_ensu", timeSearch:"shared/quartersearch", myObject:"ensu", loaded:ensuLoaded, fileWindow: true},
			{caption:"Reporte Mensual de Violencia", myAction:"/months/load_violence_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:violenceReportLoaded, fileWindow: true},
			{caption:"Cifras delictivas mensuales", myAction:"/months/load_crime_victim_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:crimeVictimReportLoaded, fileWindow: true},
			{caption:"Crear irco estatal", myAction:"/states/load_irco", timeSearch:"shared/quartersearch", myObject: nil, loaded:nil},
			{caption:"Crear irco municipal", myAction:"/counties/load_irco", timeSearch:"shared/quartersearch", myObject: nil, loaded:nil},
			{caption:"Cambiar nombre a organización", myAction:"/organizations/new_name", timeSearch:"shared/cartelsearch", myObject: "name", loaded:nil}
		]
	end

	def load_ensu

		myName = load_ensu_params[:year]+"_"+load_ensu_params[:quarter]
		myQuarter = Quarter.where(:name=>myName).last		
		myQuarter.ensu.purge
		myQuarter.ensu.attach(load_ensu_params[:ensu])

		if myQuarter.ensu.attached?
			session[:filename] = load_ensu_params[:ensu].original_filename
			session[:load_success] = true
		end


		# CHECK CSV FILE STRUCTURE
		myFile = myQuarter.ensu.download
		myFile = myFile.force_encoding("UTF-8")
		rawData = myFile

		ensuArr = []
		rawData.each_line{|l| line = l.split(","); ensuArr.push(line)}
		ensuArr.each{|x|x.each{|y|y.strip!}}


		l = ensuArr.length-1

		State.all.each{|state|
			stateArr = []
			statePopulation = 0
			feel_safe = 0
			state.ensu_cities.each{|city|
				(0..l).each{|x|
					if ensuArr[x][0]
						if ensuArr[x][0] == city and ensuArr[x][1] !=""
							cityArr = []
							statePopulation += ensuArr[x][1].delete(' ').to_i
							cityArr.push(ensuArr[x][0],ensuArr[x][1].delete(' ').to_i,ensuArr[x+1][4].to_f)
							stateArr.push(cityArr)
						end
					end
				}
			}
			stateArr.each{|y|
				myShare = ((y[1].to_f/statePopulation.to_f))
				myPoints = myShare*y[2]
				feel_safe += myPoints
			}
		}
		redirect_to "/datasets/load"
	end

	def basic
		@forms = [
			{caption:"countyScript", myAction:"/datasets/load_counties", myObject:"csv"},
			{caption:"killingScript", myAction:"/datasets/load_killings", myObject:"csv"}
		]
	end 	

	def victims_query
		helpers.clear_session
		session[:checkedYearsArr] = []
		years = helpers.get_regular_years
		years.each {|year|
			session[:checkedYearsArr].push(year.id)
		}
		session[:checkedStatesArr] = []
		states = State.all.sort
		stateArr = []
		states.each{|state|
			session[:checkedStatesArr].push(state.id)	
			stateArr.push(state.id)
		}
		session[:checkedCitiesArr] = []
		cities = City.all.sort_by {|city| city.name}
		citiesArr = []
		cities.each{|city|
			session[:checkedCitiesArr].push(city.id)	
			citiesArr.push(city.id)
		}
		genderOptions = ["Masculino","Femenino","No identificado"]
		session[:checkedGenderOptions] = genderOptions
		countiesArr = []
		session[:victim_freq_params] = ["annual","stateWise","noGenderSplit", years, stateArr, citiesArr, genderOptions, countiesArr]
		redirect_to "/datasets/victims"
		session[:checkedCounties] = "states"
	end

	def post_victim_query
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
		else
			session[:checkedCounties] = "states"
		end
		session[:checkedCitiesArr] = victim_freq_params[:freq_cities]
		session[:checkedCitiesArr] = session[:checkedCitiesArr].map(&:to_i)
		session[:victim_freq_params][5] = session[:checkedCitiesArr]
		redirect_to "/datasets/victims"
	end

	def victims
		@key = Rails.application.credentials.google_maps_api_key
		@my_freq_table = victim_freq_table(session[:victim_freq_params][0],session[:victim_freq_params][1],session[:victim_freq_params][2],session[:victim_freq_params][3],session[:victim_freq_params][4],session[:victim_freq_params][5],session[:victim_freq_params][6],session[:checkedCounties])
		@timeFrames = [
  			{caption:"Anual", box_id:"annual_query_box", name:"annual"},
			{caption:"Trimestral", box_id:"quarterly_query_box", name:"quarterly"},
			{caption:"Mensual", box_id:"monthly_query_box", name:"monthly"},
  		]
  		@placeFrames = [
  			{caption:"Nacional", box_id:"nation_query_box", name:"nationWise"},
  			{caption:"Estado", box_id:"state_query_box", name:"stateWise"},
			{caption:"Z Metropolitana", box_id:"city_query_box", name:"cityWise"},
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
  		@years = helpers.get_regular_years
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

  		@county_toast_message = "Utilice la sección de Filtros para seleccionar estado y municipios"

  		if @stateWise || @cityWise
  			if @genderFrames[0][:checked]
  				@maps = true
  			elsif @checkedGenderOptions.length == 1
  				@maps = true
  			end
  		end
  		# @lastDay = helpers.lastDay("victims")
	end

	def load_victim_freq_table
		years = Year.all
		tablesArr = [
			{:scope=>"stateWise", :regions=>State.all, :periods=>helpers.get_specific_years(years, "victims"), :category=>"state_annual_noGenderSplit_victims"},
			{:scope=>"countyWise", :regions=>County.all, :periods=>helpers.get_specific_years(years, "victims"), :category=>"county_annual_noGenderSplit_victims"}
		] 
		
		tablesArr.each{|x|
			myArr = []
			totalHash = {}
			totalFreq = []
			(1..x[:periods].length).each {
				totalFreq.push(0)
			}

			x[:regions].each{|place|
				unless place.victims.empty?
					placeHash = {}
					placeHash[:name] = place.name
					if x[:scope] == "countyWise"
						placeHash[:parent_name] = place.state.shortname
					end
					freq = []
					counter = 0
					place_total = 0
					localVictims = place.victims
					x[:periods].each {|timeUnit|
						number_of_victims = localVictims.merge(timeUnit.victims).length
						freq.push(number_of_victims)
						totalFreq[counter] += number_of_victims
						counter += 1
						place_total += number_of_victims
					}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total
					myArr.push(placeHash)
				end
			}
			totalHash[:freq] = totalFreq
			total_total = 0
			totalFreq.each{|q|
				total_total += q
			}
			totalHash[:total_total] = total_total
			myArr.push(totalHash)
			Cookie.create(:data=>myArr, :category=>x[:category])
		}

		
		redirect_to '/datasets/load'
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

	def sort
		if params[:type] == "victims"
			redirect_to "/datasets/victims"
		end
	end

    def loadApi
        myHash = {}
        stateArr = []
        State.all.each{|state|
        	stateHash = {}
        	stateHash[:code] = state.code
        	stateHash[:name] = state.name
        	stateHash[:shortname] = state.shortname
        	stateHash[:population] = state.population
        	countyArr = []
        	state.counties.each{|county|
        		countyHash = {}
        		countyHash[:code] = county.full_code
        		countyHash[:name] = county.name
        		countyHash[:shortname] = county.shortname
        		countyHash[:population] = county.population
        		countyArr.push(countyHash)
        	}
        	stateHash[:conties] = countyArr
        	stateArr.push(stateHash)
        }
        stateArr = stateArr.sort_by{|state| state[:code]}
        myHash[:states_and_counties] = stateArr
 
        # LAST UPDATE
        lastKilling = Killing.all.sort_by{|k| k.event.event_date}.last
        thisMonth = Event.find(lastKilling.event_id).month
        lastDay = Event.find(lastKilling.event_id).event_date

        myHash[:lastUpdate] = Date.civil(lastDay.year, lastDay.month, -1)

        # TOTAL VICTIMS PER YEAR (WITH ESTIMATE FOR CURRENT YEAR)
        myYears = helpers.get_regular_years
        thisYear = Year.where(:name=>Time.now.year.to_s).last
        victimYearsArr = []
        myYears.each{|year|
            yearHash = {}
            yearHash[:year] = year.name.to_i
            genderHash = {}
            if year != thisYear
                yearHash[:victims] = year.victims.length
                genderHash[:maleVictims] = year.victims.where(:gender=>"Masculino").length
                genderHash[:femaleVictims] = year.victims.where(:gender=>"Femenino").length
                genderHash[:undefined] = year.victims.where(:gender=>"").length
                yearHash[:estimate] = false
            else
                n = helpers.get_specific_months([thisYear], "victims").length
                unless n == 0
                    yearHash[:victims] = year.victims.length*(12/n)
                    if n == 12
                        yearHash[:estimate] = false        
                    else
                        yearHash[:estimate] = true
                    end
                end
            end
            yearHash[:victimsGender] = genderHash
            victimYearsArr.push(yearHash)
        }
        myHash[:years] = victimYearsArr

        # MONTHLY VICITMS FOR 5 MOST VIOLENT STATE (PREVIOUS 12 MONTHS) 
        topStatesArr = []
        State.all.each{|state|
            stateHash = {}
            stateHash[:code] = state.code
            stateHash[:name] = state.name
            stateHash[:shortname] = state.shortname
            r = 11..0
            stateHash[:totalVictims] = 0
            stateHash[:months] = []
            localVictims = state.victims
            (r.first).downto(r.last).each {|x|
                monthHash = {}
                monthHash[:month] = (thisMonth.first_day - (x*28).days).strftime('%m-%Y')
                monthHash[:victims] = Month.where(:name=>(thisMonth.first_day - (x*28).days).strftime('%Y_%m')).last.victims.merge(localVictims).length
                stateHash[:totalVictims] += monthHash[:victims]
                stateHash[:months].push(monthHash)
            }
            topStatesArr.push(stateHash)
        }
        topStatesArr = topStatesArr.sort_by{|state| -state[:totalVictims]}
        myHash[:topStates] = topStatesArr[0..4]

        topCountiesArr = []
        allCountiesArr = []
        County.all.each{|county|
            unless county.name == "Sin definir"
            	unless county.victims == 0
		            countyHash = {}
		            countyHash[:code] = county.full_code
		            countyHash[:name] = county.name
		            countyHash[:shortname] = county.shortname
		            r = 11..0
		            countyHash[:totalVictims] = 0
		            countyHash[:months] = []
		            localVictims = county.victims
		            (r.first).downto(r.last).each {|x|
		                monthHash = {}
		                monthHash[:month] = (thisMonth.first_day - (x*28).days).strftime('%m-%Y')
		                monthHash[:victims] = Month.where(:name=>(thisMonth.first_day - (x*28).days).strftime('%Y_%m')).last.victims.merge(localVictims).length
		                countyHash[:totalVictims] += monthHash[:victims]
		                countyHash[:months].push(monthHash)
		            }
		            if countyHash[:months][11][:victims] > 0
		            	positiveCountyHash = {}
		            	positiveCountyHash[:code] = county.full_code
		            	positiveCountyHash[:name] = county.name
		            	positiveCountyHash[:shortname] = county.shortname
			            if countyHash[:months][11][:victims] > 20
			            	positiveCountyHash[:victimLevel] = "21 en adelante"
			            elsif countyHash[:months][11][:victims] > 10
			            	positiveCountyHash[:victimLevel] = "11 a 20"
			            else
			            	positiveCountyHash[:victimLevel] = "1 a 10"
			            end
			            allCountiesArr.push(positiveCountyHash)
		            end
		            topCountiesArr.push(countyHash)
		        end
	        end
        }

        topCountiesArr = topCountiesArr.sort_by{|county| -county[:totalVictims]}
        myHash[:countyVictimsMap] = allCountiesArr.sort_by{|county| county[:full_code]}
        myHash[:topCounties] = topCountiesArr[0..4]

        Cookie.create(:data=>[myHash], :category=>"api")
        redirect_to "/datasets/load"
    end

    def states_and_counties_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:data=>myData[:states_and_counties]}
        render json: myHash 
    end

    def year_victims_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:years]}
        render json: myHash 
    end

    def state_victims_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:topStates]}
        render json: myHash 
    end

    def county_victims_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:topCounties]}
        render json: myHash 
    end

    def county_victims_map_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:countyVictimsMap]}
        render json: myHash 
    end


	private

	def load_ensu_params
		params.require(:query).permit(:ensu,:year,:quarter)
	end

	def basic_county_params
		params.require(:file).permit(:csv)
	end

	def victim_freq_params
		params[:query][:freq_years] ||= []
		params.require(:query).permit(:freq_timeframe, :freq_placeframe, :freq_genderframe, freq_years: [], freq_states: [], freq_cities: [], freq_counties: [], freq_gender_options: [])
	end

end
