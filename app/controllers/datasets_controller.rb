class DatasetsController < ApplicationController
	
	require 'csv'
	require 'pp'
	require 'net/http'
	require 'net/https'
	require 'uri'
	require 'json'
	require 'nokogiri'

	layout false, only: [:year_victims, :state_victims, :county_victims, :county_victims_map]
	after_action :remove_load_message, only: [:load, :terrorist_panel]

	def show
	end

	def method_name
		
	end

	def terrorist_search
		@keyMembers = Member.joins(:hits).distinct

		# Definir roles permitidos
		roles_permitidos = [
		  "Líder",
		  "Operador",
		  "Familiar",
		  "Autoridad cooptada",
		  "Socio"
		]

		# Crear el hash con valores iniciales en cero
		@conteo_por_rol = roles_permitidos.index_with { 0 }

		# Consultar y agrupar miembros con al menos un hit, cuyo rol esté en roles_permitidos
		Member.joins(:hits, :role)
		      .where(roles: { name: roles_permitidos })
		      .distinct
		      .group("roles.name")
		      .count
		      .each do |rol, total|
		        @conteo_por_rol[rol] = total
		      end

		# Resultado: {"Líder"=>12, "Operador"=>34, "Familiar"=>7, ...}
		puts @conteo_por_rol

	end

	def terrorist_panel
		@myYears = ["2018","2019","2020","2021","2022","2023","2024","2025"]
		@myStates = State.all.pluck(:name).uniq
		@myStates = @myStates.sort
		@myCartels = ["CJNG", "Cártel de Sinaloa", "Cártel del Golfo", "Cártel del Noreste", "Cárteles Unidos", "La Familia Michoacana", "La Barredora", "Gente Nueva", "Tropa del Infierno", "Cártel de Zicuirán"]
		if session[:load_success]
			@load_success = true
		end
		if session[:filename]
			@filename = session[:filename]
		end
		if session[:message]
			@mesagge = session[:message]
		end

		@forms = [
			{caption:"Notas/links", myAction:"/datasets/upload_hits", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Personas", myAction:"/datasets/upload_members", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true}
		]
	end

	def upload_members
		myFile = load_members_params[:file]

		# 🔍 Roles que queremos conservar
		roles_permitidos = [
		  "Líder",
		  "Operador",
		  "Familiar",
		  "Autoridad cooptada",
		  "Socio"
		]

		# 🗂️ Contenedores por categoría
		repetidos = []
		validos = []
		invalidos = []
		correcciones_nombres = 0

		reemplazos_roles = {
			"Líder criminal" => "Líder",
			"Familiar de un criminal" => "Familiar",
			"Miembro de un grupo criminal" => "Operador",
			"Autoridad coludida" => "Autoridad cooptada",
			"Socio de un grupo criminal" => "Socio"
		}

		# 🔎 Función auxiliar para encontrar la organización
		def find_organization_by_name_or_alias(name)
			return nil if name.blank?
			normalized = name.to_s.strip.downcase

			Organization.find do |org|
				org.name.to_s.downcase == normalized ||
				org.acronym.to_s.downcase == normalized ||
				Array(org.alias).map { |a| a.downcase.strip }.include?(normalized)
			end
		end

		def corregir_nombres(fn, ln1, ln2)
			if fn.to_s.strip.split.size == 1 && ln1.to_s.strip.split.size == 1 && ln2.to_s.strip.split.size == 2
				nuevo_fn = "#{fn.strip} #{ln1.strip}"
				nuevo_ln1, nuevo_ln2 = ln2.strip.split
				return [nuevo_fn, nuevo_ln1, nuevo_ln2]
			end
			[fn, ln1, ln2] # si no aplica la heurística, devolver tal cual
		end

		CSV.foreach(myFile, headers: true, encoding: "bom|utf-8") do |row|
			role = row["role"]&.strip
			role = reemplazos_roles[role] || role

			next unless roles_permitidos.include?(role)
			original_fn  = row["firstname"]&.strip
			original_ln1 = row["lastname1"]&.strip
			original_ln2 = row["lastname2"]&.strip
			firstname, lastname1, lastname2 = corregir_nombres(original_fn, original_ln1, original_ln2)
			org_name   = row["organization"]&.strip
			legacy_id = row["legacy_id"]&.strip

			if [firstname, lastname1, lastname2] != [original_fn, original_ln1, original_ln2]
  				correcciones_nombres += 1
			end

			# Extraer los alias
			alias_string = row["alias"]&.strip
			alias_array = alias_string.present? ? alias_string.split(";").map(&:strip).uniq : []

			datos_completos = firstname.present? && lastname1.present? && lastname2.present?

			unless datos_completos
				invalidos << row.to_h
				next
			end

			myOrganization = find_organization_by_name_or_alias(org_name)
				unless myOrganization.present?
				invalidos << row.to_h
				next
			end

			myOrganization = find_organization_by_name_or_alias(org_name)

			# Buscar posibles miembros con mismo nombre completo
			miembros_potenciales = Member.joins(:organization)
				.where(
					firstname: firstname,
					lastname1: lastname1,
					lastname2: lastname2
				)
			# Verificar si alguno tiene la misma organización (resuelta por name, alias o acronym)
			repetido = miembros_potenciales.any? { |m| m.organization_id == myOrganization&.id }
			if repetido
				repetidos << row.to_h
				myMember = miembros_potenciales.reverse.find { |m| m.organization_id == myOrganization.id }

				if myMember && myMember.role_id.nil?
					rol = Role.find_or_create_by!(name: role)
					myMember.update(role: rol)
				end

				# Asignar rol si no tiene
				if myMember.role_id.nil?
					rol = Role.find_or_create_by!(name: role)
					myMember.update(role: rol)
				end
				legacy_id_valida = Hit.exists?(legacy_id: legacy_id)
				if legacy_id_valida
					myHit = Hit.find_by(legacy_id: legacy_id) 
					myMember.hits << myHit unless myMember.hits.exists?(myHit.id)
				end
				if alias_array.any?
					# Evitar nulos
					myMember.alias ||= []
					nuevos_alias = alias_array - myMember.alias
					if nuevos_alias.any?
						myMember.alias += nuevos_alias
						myMember.save!
					end
				end

				# 🆕 Si se marca como detenido
				if row["detention"].to_s.strip == "1" && myHit.present?
					hit_date = myHit.date
					town_id = myHit.town_id
					detention = Detention.find_by(legacy_id: myHit.legacy_id)

					if detention.nil?
						new_event = Event.create!(event_date: hit_date, town_id: town_id)
						detention = Detention.create!(event: new_event, legacy_id: myHit.legacy_id)
					end

					if myMember.detention.nil? || myMember.detention.event.event_date < hit_date
						myMember.update!(detention: detention)
					end
				end
				next
			end

			# Verificar si los datos básicos son válidos
			organizacion_valida = myOrganization.present?
			legacy_id_valida = Hit.exists?(legacy_id: legacy_id)
			if legacy_id_valida
				myHit = Hit.find_by(legacy_id: legacy_id) 
			end
			if datos_completos && organizacion_valida && legacy_id_valida
				validos << row.to_h
				rol = Role.find_or_create_by!(name: role)
				myMember = Member.create!(
					firstname: firstname,
			    	lastname1: lastname1,
			    	lastname2: lastname2,
			    	organization: myOrganization, 
			    	alias: alias_array,
			    	role: rol
			    )

			    myMember.hits << myHit

				if row["detention"].to_s.strip == "1" && myHit.present?
					hit_date = myHit.date
					town_id = myHit.town_id
					detention = Detention.find_by(legacy_id: myHit.legacy_id)
					if detention.nil?
						new_event = Event.create!(event_date: hit_date, town_id: town_id)
						detention = Detention.create!(event: new_event, legacy_id: myHit.legacy_id)
					end
					myMember.update!(detention: detention)
				end
			else
				invalidos << row.to_h
			end
		end

		session[:filename] = load_members_params[:file].original_filename
		session[:load_success] = true
		session[:message] = "🔁 Repetidos: #{repetidos.count}"+"\n"+
			"✅ Válidos:   #{validos.count}"+"\n"+
			"⚠️ Inválidos: #{invalidos.count}" + "\n" +
			"✏️ Nombres corregidos: #{correcciones_nombres}"


		csv_string = CSV.generate(headers: true) do |csv|
		  csv << ["legacy_id", "firstname", "lastname1", "lastname2", "alias", "role", "organization", "detention"]
		  invalidos.each do |row|
		    csv << [
		      row["legacy_id"],
		      row["firstname"],
		      row["lastname1"],
		      row["lastname2"],
		      row["alias"],
		      row["role"],
		      row["organization"],
		      row["detention"]
		    ]
		  end
		end

		# Guardar CSV en archivo temporal
		filename = "invalid_members_#{Time.now.to_i}.csv"
		filepath = Rails.root.join("tmp", filename)
		File.write(filepath, csv_string)

		# Guardar el nombre en sesión para usarlo en la vista
		session[:invalid_members_csv] = filename

		redirect_to '/datasets/terrorist_panel'
	end

	def download_invalid_members
		filename = params[:filename]
		filepath = Rails.root.join("tmp", filename)

		if File.exist?(filepath)
			send_file filepath, filename: filename, type: "text/csv"
		else
			redirect_to '/datasets/terrorist_panel', alert: "El archivo ya no está disponible."
		end
	end

	def load
		@quarters = Quarter.all.sort
		@months = Month.all.sort
		ensuLoaded = []
		violenceReportLoaded = []
		socialReportLoaded = []
		forecastReportLoaded = []
		crimeVictimReportLoaded = []
		briefingLoaded = []
		@quarters.each{|quarter|
			if quarter.ensu.attached?
				ensuLoaded.push(quarter.name)
			end
		}
		@months.each{|month|
			if month.violence_report.attached?
				violenceReportLoaded.push(month.name)
			end
			if month.social_report.attached?
				socialReportLoaded.push(month.name)
			end
			if month.forecast_report.attached?
				forecastReportLoaded.push(month.name)
			end
			if month.crime_victim_report.attached?
				crimeVictimReportLoaded.push(month.name)
			end
		}
		myFiles = Dir['public/briefings/*'].sort { |a, b| a.downcase <=> b.downcase }
    	myFiles.each{|file|
    		# myHash = {}
    		# myHash[:path] = file[7..-1]
    		# myHash[:number] = file[34..36]
    		myString = file[34..36]
    		# myMonth = Month.where(:name=>myString).last
    		# myHash[:month] = I18n.l(myMonth.first_day, format: '%B de %Y')
    		briefingLoaded.push(myString)
    	}
    	briefingLoaded = briefingLoaded[-31..-1]


		@cartels = helpers.get_cartels
		if session[:load_success]
			@load_success = true
		end
		if session[:filename]
			@filename = session[:filename]
		end
		if session[:bad_briefing]
			@bad_briefing = true
		end
		@myYears = (2010..2030)
		@forms = [
			{caption:"Víctimas", myAction:"/victims/load_victims", timeSearch: "shared/monthsearch", myObject:"file", loaded: nil, fileWindow: true},
			{caption:"ICon", myAction:"/states/load_icon", timeSearch: "shared/quartersearch", myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Perfil OC", myAction:"/organizations/load_organizations", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Referencias-Incidentes OC", myAction:"/organizations/load_organization_events", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Presencia estatal-municipal OC", myAction:"/organizations/load_organization_territory", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"Detenciones", myAction:"/members/detentions", timeSearch: nil, myObject:"file", loaded: nil, fileWindow: true},
			{caption:"ENSU BP1_1", myAction:"/datasets/load_ensu", timeSearch:"shared/quartersearch", myObject:"ensu", loaded:ensuLoaded, fileWindow: true},
			{caption:"Reporte de Violencia del Crimen Organizado", myAction:"/months/load_violence_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:violenceReportLoaded, fileWindow: true},
			{caption:"Reporte de Riesgo Social", myAction:"/months/load_social_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:socialReportLoaded, fileWindow: true},
			{caption:"Prospectiva", myAction:"/months/load_forecast_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:forecastReportLoaded, fileWindow: true},
			{caption:"Briefing semanal", myAction:"/datasets/load_briefing", timeSearch: nil, myObject:"report", loaded:briefingLoaded, fileWindow: true},
			{caption:"Cifras delictivas mensuales", myAction:"/months/load_crime_victim_report", timeSearch:"shared/monthsearch", myObject:"report", loaded:crimeVictimReportLoaded, fileWindow: true},
			{caption:"Crear irco estatal", myAction:"/states/load_irco", timeSearch:"shared/quartersearch", myObject: nil, loaded:nil},
			{caption:"Crear datos para irco estatal", myAction:"/states/stateIndexHash", timeSearch:"shared/quartersearch", myObject: nil, loaded:nil},
			{caption:"Crear irco municipal", myAction:"/counties/load_irco", timeSearch:"shared/quartersearch", myObject: nil, loaded:nil},
			{caption:"Cambiar nombre a organización", myAction:"/organizations/new_name", timeSearch:"shared/cartelsearch", myObject: "name", loaded:nil}
		]
	end

	def api_control
		@forms = [
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

	def load_briefing
		myFile = load_briefing_params[:report]
		regex = /^Briefing_Semanal_\d{3}_Lantia_Intelligence_\d{8}_.pdf$/
		if !!(myFile.original_filename =~ regex)
			dir = Rails.root.join('public','briefings')
			File.open(dir.join(myFile.original_filename), 'wb') do |file|
  				file.write(myFile.read)
			end
			session[:load_success] = true
			session[:filename] = myFile.original_filename
		else
			session[:bad_briefing] = true
		end
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
  		@county_toast_message = 'Seleccione estado y municipios en "Filtros"'
  		unless session[:victim_freq_params][1] == "nationWise"
			if @genderFrames[0][:checked]
				@maps = true
			elsif @checkedGenderOptions.length == 1
				@maps = true
			end
		end
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
        # CHANGE THIS IN JANUARY!!!
        # thisYear = Year.where(:name=>Time.now.year.to_s).last
        thisYear = Year.where(:name=>"2024").last
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
                    yearHash[:victims] = year.victims.length*(12/n.to_f)
                    print "OOoo"*100
                    print yearHash[:victims]
                    yearHash[:victims] = yearHash[:victims].round(0)
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
        myHash[:topStates] = topStatesArr[0..3]

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
		            topCountiesArr.push(countyHash)
		            if county.population
			            if county.population > 200000
			            	positiveCountyHash = {}
			            	positiveCountyHash[:code] = county.full_code
			            	positiveCountyHash[:name] = county.name
			            	positiveCountyHash[:shortname] = county.shortname
			            	positiveCountyHash[:latitude] = county.towns.where(:code=>"0000").last.latitude
			            	positiveCountyHash[:longitude] = county.towns.where(:code=>"0000").last.longitude
				        	if countyHash[:totalVictims] > 240
				        		positiveCountyHash[:victimLevel] = "21 en adelante"
				        	elsif countyHash[:totalVictims] > 120
				        		positiveCountyHash[:victimLevel] = "11 a 20"
				        	elsif countyHash[:totalVictims] > 12
				        		positiveCountyHash[:victimLevel] = "1 a 10"
				        	else
				        		positiveCountyHash[:victimLevel] = "menos de 1"	
				        	end
				        	allCountiesArr.push(positiveCountyHash)
			        	end
			        end
		        end
	        end
        }

        topCountiesArr = topCountiesArr.sort_by{|county| -county[:totalVictims]}
        myHash[:countyVictimsMap] = allCountiesArr.sort_by{|county| county[:full_code]}
        myHash[:topCounties] = topCountiesArr[0..3]
        Cookie.create(:data=>[myHash], :category=>"api")
        redirect_to "/datasets/api_control"
    end

    def load_featured_state
    	myState = State.where(:name=>"Guerrero").last
    	levels = helpers.ircoLevels
    	myHash = {}
    	irco = Cookie.where(:category=>"irco").last.data
    	myHash[:quarter] = irco[0][:evolution_score].last[:string] 
    	myHash[:state] = {:code=>myState.code, :name=>myState.name, :shortname=>myState.shortname}
    	irco.each{|x|
    		if x[:state].id == myState.id
    			myHash[:irco] = {:score=>x[:irco][:score]}
    			myHash[:irco][:level] = x[:level]
    			myHash[:irco][:trend] = x[:trend]
    			myHash[:irco][:rank] = x[:rank].to_i
    			myHash[:irco][:n] = 32
    		end
    	}
    	myHash[:irco][:score] =  myHash[:irco][:score]*10
        myHash[:irco][:score] = myHash[:irco][:score].round()
    	myRackets = {}
    	cartel_id = League.where(:name=>"Cártel").last.id
    	mafia_id = League.where(:name=>"Mafia").last.id
    	band_id = League.where(:name=>"Banda").last.id
    	myRackets[:n] = myState.rackets.uniq.length
    	myRackets[:cartels] = myState.rackets.where(:mainleague=>cartel_id).uniq.pluck(:name).sort
    	myRackets[:mafias] = myState.rackets.where(:mainleague=>mafia_id).uniq.pluck(:name).sort
    	myRackets[:bands] = myState.rackets.where(:mainleague=>band_id).uniq.pluck(:name).sort
    	myHash[:rackets] = myRackets
    

    	Cookie.create(:data=>[myHash], :category=>"featured_state_api")
    	redirect_to "/featured_state_api"
    end

    def load_featured_county
    	myCounty = County.where(:full_code=>"09015").last
    	levels = helpers.ircoLevels
    	myHash = {}
    	irco = Cookie.where(:category=>"irco_counties").last.data
    	myHash[:quarter] = irco[0][:evolution_score].last[:string]
    	myHash[:county] = {:code=>myCounty.full_code, :name=>myCounty.name, :shortname=>myCounty.shortname}
    	irco.each{|x|
    		if x[:county].id == myCounty.id
    			myHash[:irco] = {:score=>x[:irco][:score]}
    			myHash[:irco][:level] = x[:level]
    			myHash[:irco][:trend] = x[:trend]
    			myHash[:irco][:rank] = x[:rank].to_i
    			myHash[:irco][:n] = helpers.bigCounties.length
    		end
    	}
    	myHash[:irco][:score] =  myHash[:irco][:score]*10
        myHash[:irco][:score] = myHash[:irco][:score].round()
    	myRackets = {}
    	cartel_id = League.where(:name=>"Cártel").last.id
    	mafia_id = League.where(:name=>"Mafia").last.id
    	band_id = League.where(:name=>"Banda").last.id
    	myRackets[:n] = myCounty.rackets.uniq.length
    	myRackets[:cartels] = myCounty.rackets.where(:mainleague=>cartel_id).uniq.pluck(:name).sort
    	myRackets[:mafias] = myCounty.rackets.where(:mainleague=>mafia_id).uniq.pluck(:name).sort
    	myRackets[:bands] = myCounty.rackets.where(:mainleague=>band_id).uniq.pluck(:name).sort
    	myHash[:rackets] = myRackets
    

    	Cookie.create(:data=>[myHash], :category=>"featured_county_api")
    	redirect_to "/featured_county_api"
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

    def year_victims
        previousYears = [
        	{:year=>"2007",:victims=>2826},
        	{:year=>"2008",:victims=>6837},
        	{:year=>"2009",:victims=>9614},
        	{:year=>"2010",:victims=>15266},
        	{:year=>"2011",:victims=>15768},
        	{:year=>"2012",:victims=>13675},
        	{:year=>"2013",:victims=>11269},
        	{:year=>"2014",:victims=>8004},
        	{:year=>"2015",:victims=>8122},
        	{:year=>"2016",:victims=>12224},
        	{:year=>"2017",:victims=>18946}
        ]
        victimYearsArr = Cookie.where(:category=>"api").last.data[0][:years]
        @yearData = previousYears.append(*victimYearsArr)
        @yearData[0][:change] = "--"
        (1..@yearData.length-1).each{|x|
        	change = @yearData[x][:victims]/@yearData[x-1][:victims].to_f
        	@yearData[x][:change] = ((change - 1)*100).round(1)
        }
    end

    def state_victims_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:topStates]}
        render json: myHash 
    end

    def state_victims
    	colorAxis = ["#2f8f8f", "#ef974e", "#3ebf3e", "#757575"]
    	@placeData = Cookie.where(:category=>"api").last.data[0][:topStates]
    	(0..3).each{|x|
    		@placeData[x][:color] = colorAxis[x]
    	}
    end

    def county_victims_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:topCounties]}
        render json: myHash 
    end

    def county_victims
    	colorAxis = ["#2f8f8f", "#ef974e", "#3ebf3e", "#757575"]
    	@placeData = Cookie.where(:category=>"api").last.data[0][:topCounties]
    	(0..3).each{|x|
    		@placeData[x][:color] = colorAxis[x]
    	}
    end

    def county_victims_map_api
        myData = Cookie.where(:category=>"api").last.data[0]
        myHash = {:lastUpdate=>myData[:lastUpdate], :data=>myData[:countyVictimsMap]}
        render json: myHash 
    end

    def county_victims_map
    	@mapData = Cookie.where(:category=>"api").last.data[0][:countyVictimsMap]
    end

    def featured_state_api
        myData = Cookie.where(:category=>"featured_state_api").last.data[0]
        myHash = {:data=>myData}
    	render json: myHash
    end

    def featured_county_api
        myData = Cookie.where(:category=>"featured_county_api").last.data[0]
        myHash = {:data=>myData}
    	render json: myHash
    end

    def downloads
    	@v_months = Month.joins(:violence_report_attachment).sort { |a, b| b <=> a }
    	@s_months = Month.joins(:social_report_attachment).sort { |a, b| b <=> a }
    	@f_months = Month.joins(:forecast_report_attachment).sort { |a, b| b <=> a }
    	myFiles = Dir['public/briefings/*'].sort { |a, b| b.downcase <=> a.downcase }
    	@briefings = []
    	myFiles.each{|file|
    		myHash = {}
    		myHash[:path] = file[7..-1]
    		myHash[:number] = file[34..36]
    		myString = file[62..65]+"_"+file[60..61]
    		myMonth = Month.where(:name=>myString).last
    		myHash[:month] = I18n.l(myMonth.first_day, format: '%B de %Y')
    		@briefings.push(myHash)
    	}
    end

	def upload_hits
		loaded = 0
		skipped = 0
		errors = []
		myFile = load_hit_params[:file]
		CSV.foreach(myFile, headers: true, encoding: "bom|utf-8") do |row|
			legacy_id = row["legacy_id"]&.strip
			date      = Date.parse(row["fecha"]) rescue nil
			state_name = row["estado"]&.strip
			municipality_name = row["municipio o localidad"]&.strip
			clave = row["clave INEGI"]&.strip
			clave = clave.rjust(5, "0") if clave.present? # Normaliza clave a 6 dígitos
			title = row["título"]&.strip
			report = row["reporte"]&.strip
			link = row["link"]&.strip

	    # Validación: legacy_id único
	    if Hit.exists?(legacy_id: legacy_id)
			skipped += 1
			next
	    end

	    # Validación: fecha válida
	    if date.nil?
			errors << { legacy_id: legacy_id, error: "Fecha inválida" }
			next
	    end

	    # Validación: determinar el town por clave INEGI o nombre del estado
	    town = nil

	    if clave.present?
	    	clave = clave + "0000"
	    	unless Town.find_by(full_code: clave).nil?
	    		town = Town.find_by(full_code: clave).id
	    	end
	    end

	    if town.nil? && state_name.present?
			state = State.find_by(name: state_name)
			clave = state.code + "0000000"
			town = Town.find_by(full_code: clave).id
	    end

	    if town.nil?
			errors << { legacy_id: legacy_id, error: "No se encontró municipio ni estado" }
			next
	    end

	    # Validación: link único o reporte presente
	    link_valido = link.present? && !Hit.exists?(link: link)
	    tiene_reporte = report.present?

	    unless link_valido || tiene_reporte
			errors << { legacy_id: legacy_id, error: "Sin link válido ni reporte" }
			next
	    end

	    # Crear el hit
	    Hit.create!(
			legacy_id: legacy_id,
			date: date,
			title: title,
			link: link,
			report: report,
			town_id: town
	    )
	    loaded += 1
		rescue => e
			errors << { legacy_id: legacy_id, error: e.message }
			next
		end

		puts "✅ Hits cargados: #{loaded}"
		puts "⚠️ Hits omitidos (legacy_id duplicado): #{skipped}"
		puts "❌ Errores:"
		errors.each { |e| puts e.inspect }
	  	session[:filename] = load_hit_params[:file].original_filename
		session[:load_success] = true
		session[:message] = "✅ Hits cargados: #{loaded} \n ⚠️ Hits omitidos (legacy_id duplicado): #{skipped}"
		redirect_to '/datasets/terrorist_panel'
	end

	def search
		@cartels = Sector.where(:scian2=>98).last.organizations.uniq
	end

	def web_scrape

		def build_duckduckgo_url(query, offset)
			base_url = 'https://html.duckduckgo.com/html/'
			"#{base_url}?q=#{URI.encode_www_form_component(query)}&s=#{offset}"
		end

		def fetch_html_with_scrapingbee(url)
			api_key = '7F4T3OWDZ2MS5CJN7RF6K7E9XVTBR0RFXXZYQD9U5C2G430S09JTMLUCKTQRUQRG3B292VW5RC6O6FUK' 
			uri = URI('https://app.scrapingbee.com/api/v1/')
			params = {
			api_key: api_key,
			url: url,
			render_js: false,
			block_resources: true
			}
			uri.query = URI.encode_www_form(params)

			res = Net::HTTP.get_response(uri)

			html = res.body
			html.force_encoding('UTF-8')
			html.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
		end

		def extract_links_from_duckduckgo(html)
			doc = Nokogiri::HTML(html)
			links = []

			doc.css('a.result__a').each do |a|
				href = a['href']
				# if href.include?('milenio.com')
				links << href
			end

			links.uniq
		end

		year = scraping_params[:year]
		if year == "2025"
			months = %w[enero febrero marzo abril]
		else
			months = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]
		end
		cartel = scraping_params[:cartel]
		state = scraping_params[:state]
		if scraping_params[:domain]
			myDomain = scraping_params[:domain]
		else
			puts "XXxx"*1000 +"Domain empty"
		end
		pages_per_month = 1
		all_links = []
		Dir.mkdir('htmls') unless Dir.exist?('htmls')

		months.each do |month|
			puts "\n📅 Procesando: #{month.capitalize} #{year}"

			pages_per_month.times do |i|
				offset = i * 30
				query = "#{cartel} #{month} #{year} #{state}"
				if myDomain
					query = query + " site: #{myDomain}"
				end
				url = build_duckduckgo_url(query, offset)

				puts "🔎 Página #{i + 1} — Offset #{offset}"
				html = fetch_html_with_scrapingbee(url)

				# Guardar HTML por si querés inspeccionar
				File.write("htmls/duck_cjng_#{month}_#{year}_p#{i + 1}.html", html)

				links = extract_links_from_duckduckgo(html)
				puts "   ↳ Se encontraron #{links.size} enlaces"
				all_links.concat(links)

				sleep(2)
			end
		end

		filename = "tmp/scraped_links_#{SecureRandom.hex(10)}.json"
		File.write(filename, all_links.uniq.to_json)
		session[:scraped_links_file] = filename
		redirect_to '/datasets/terrorist_panel'
	end

	def download_scraped_links
		if session[:scraped_links_file] && File.exist?(session[:scraped_links_file])
			links = JSON.parse(File.read(session[:scraped_links_file])) rescue []

			csv_data = CSV.generate do |csv|
				csv << ['Enlace']
				links.each { |link| csv << [link] }
			end
				send_data csv_data, filename: "enlaces_scrapeados_#{Time.zone.now.to_date}.csv", type: 'text/csv'
			else
				redirect_to '/datasets/terrorist_panel'
			end
	end

	private

	def load_ensu_params
		params.require(:query).permit(:ensu,:year,:quarter)
	end

	def load_briefing_params
		params.require(:query).permit(:report)
	end

	def basic_county_params
		params.require(:file).permit(:csv)
	end

	def victim_freq_params
		params[:query][:freq_years] ||= []
		params.require(:query).permit(:freq_timeframe, :freq_placeframe, :freq_genderframe, freq_years: [], freq_states: [], freq_cities: [], freq_counties: [], freq_gender_options: [])
	end

	def load_hit_params
		params.require(:query).permit(:file)
	end

	def load_members_params
		params.require(:query).permit(:file)
	end

	def scraping_params
		params.require(:query).permit(:year, :cartel, :state, :domain)
	end

end
