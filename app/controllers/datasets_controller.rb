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

		if session[:load_success]
			@load_success = true
		end

		if session[:filename]
			@filename = session[:filename]
		end

		@myYears = (2010..2030)
		@forms = [
			{caption:"ENSU BP1_1", myAction:"/datasets/load_ensu", timeSearch:"shared/quartersearch", myObject:"ensu", loaded:ensuLoaded},
			{caption:"Reporte Mensual de Violencia", myAction:"/months/load_violence_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:violenceReportLoaded},
			{caption:"Cifras delictivas mensuales", myAction:"/months/load_crime_victim_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:crimeVictimReportLoaded}
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
			print "*******ATTACHEMENT WORKED: "
			print "TRUE"
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
				print y
				myShare = ((y[1].to_f/statePopulation.to_f))
				myPoints = myShare*y[2]
				feel_safe += myPoints
			}
			print state.name+','+feel_safe.to_s+'************'+"\n"
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
		years = helpers.get_regular_years
		session[:victim_freq_params] = ["annual","stateWise","noGenderSplit", years]
		redirect_to "/datasets/victims"
	end

	def post_victim_query
		print "OOoo"*1000
		pp victim_freq_params
		if victim_freq_params[:freq_timeframe]
			session[:victim_freq_params][0] = victim_freq_params[:freq_timeframe]
		end
		if victim_freq_params[:freq_placeframe]
			session[:victim_freq_params][1] = victim_freq_params[:freq_placeframe]
		end
		if victim_freq_params[:freq_genderframe]
			print "************"
			print "WORKING ON: Gender"
			session[:victim_freq_params][2] = victim_freq_params[:freq_genderframe]
		end
		if victim_freq_params[:freq_years]
			myArr = []
			victim_freq_params[:freq_years].each{|id|
				print "************"
				print "WORKING ON: "
				print id 
				myArr.push(Year.find(id))
			}
			session[:victim_freq_params][3] = myArr
		end
		pp session[:victim_freq_params][3]
		redirect_to "/datasets/victims"
	end

	def victims
		@victim_freq_table = victim_freq_table(session[:victim_freq_params][0],session[:victim_freq_params][1],session[:victim_freq_params][2],session[:victim_freq_params][3])
		@timeFrames = [
  			{caption:"Anual", box_id:"annual_query_box", name:"annual"},
			{caption:"Trimestral", box_id:"quarterly_query_box", name:"quarterly"},
			{caption:"Mensual", box_id:"monthly_query_box", name:"monthly"},
  		]
  		@placeFrames = [
  			{caption:"Estado", box_id:"state_query_box", name:"stateWise"},
			{caption:"Zona Metropolitana", box_id:"city_query_box", name:"cityWise"},
			{caption:"Municipio", box_id:"county_query_box", name:"countyWise"},
  		]
  		@genderFrames = [
  			{caption:"No desagregar", box_id:"no_gender_split_query_box", name:"noGenderSplit"},
			{caption:"Desagregar", box_id:"gender_split_query_box", name:"genderSplit"},
  		]

  		if session[:victim_freq_params][0] == "annual"
  			@timeFrames[0][:checked] = true
  		elsif session[:victim_freq_params][0] == "quarterly"
  			@timeFrames[1][:checked] = true
  		elsif session[:victim_freq_params][0] == "monthly"
  			@timeFrames[2][:checked] = true
  		end

  		if session[:victim_freq_params][1] == "stateWise"
  			@placeFrames[0][:checked] = true
  		elsif session[:victim_freq_params][1] == "cityWise"
  			@placeFrames[1][:checked] = true
  		elsif session[:victim_freq_params][1] == "countyWise"
  			@placeFrames[2][:checked] = true
  		end

  		if session[:victim_freq_params][2] == "noGenderSplit"
  			@genderFrames[0][:checked] = true
  		elsif session[:victim_freq_params][2] == "genderSplit"
  			@genderFrames[1][:checked] = true
  		end
  		@years = helpers.get_regular_years
  		@checkedYears = session[:victim_freq_params][3]
	end

	def victim_freq_table(period, scope, gender, years)
		myTable = []
		headerHash = {}
		
		if scope == "stateWise"
			headerHash[:scope] = "ESTADO" 
			myScope = State.all.sort
		elsif scope == "cityWise"
			headerHash[:scope] = "ZONA METROPOLITANA"
			myScope = City.all.sort_by {|city| city.name}
		elsif scope == "countyWise"
			headerHash[:pre_scope] = "ESTADO"
			headerHash[:scope] = "MUNICIPIO"
			myScope = County.all.sort_by {|county| county.full_code}							
		end

		if period == "annual"
			myPeriod = helpers.get_specific_years(years)
		elsif period == "quarterly"
			myPeriod = helpers.get_regular_quarters
		elsif period == "monthly"
			myPeriod = helpers.get_regular_months
		end
		headerHash[:period] = myPeriod
		if gender == "noGenderSplit"
			myTable.push(headerHash)
			myScope.each {|place|
				placeHash = {}
				placeHash[:name] = place.name
				if scope == "countyWise"
					placeHash[:parent_name] = place.state.shortname
				end
				freq = []
				myPeriod.each {|timeUnit|
					number_of_victims = timeUnit.victims.merge(place.victims).length
					freq.push(number_of_victims)
				}
				placeHash[:freq] = freq
				myTable.push(placeHash)
			}
		else
			headerHash[:gender] = "SEXO"
			myTable.push(headerHash)
			myScope.each {|place|
				["Masculino","Femenino",nil].each{|gender|
					placeHash = {}
					placeHash[:name] = place.name
					if scope == "countyWise"
						placeHash[:parent_name] = place.state.shortname
					end
					if gender == nil
						placeHash[:gender] = "No identificado"
					else
						placeHash[:gender] = gender
					end
					freq = []
					myPeriod.each {|timeUnit|
						number_of_victims = timeUnit.victims.where(:gender=>gender).merge(place.victims).length
						freq.push(number_of_victims)
					}
					placeHash[:freq] = freq
					myTable.push(placeHash)
				}
			}
		end
		print "************"
		print "SESSSION VICTIM FREQ PARAMS"
		pp session[:victim_freq_params]
		return myTable
	end

	def get_victim_freq(timeUnit, place, gender)
		
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
		params.require(:query).permit(:freq_timeframe, :freq_placeframe, :freq_genderframe, freq_years: [])
	end

end
