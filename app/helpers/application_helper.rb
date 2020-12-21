module ApplicationHelper

	def get_years
		myArr = []
		target = Event.pluck(:event_date).uniq
		n = target.length - 1
		myRange = (1..n)
		myRange.each{|x|
			myArr.push(target[x].year)
		}
		myYears = myArr.uniq
		return	myYears
	end

	def get_regular_years
		myYears = []
		Year.all.each{|year|
			unless year.victims.empty?
				myYears.push(year)
			end
		}
		return myYears
	end

	def get_specific_years(years, unit)
		myYears = []
		years.each{|thisYear|
			year = Year.find(thisYear["id"])
			if unit == "victims"
				unless year.victims.empty?
					myYears.push(year)
				end
			end
		}
		return myYears	
	end

	def get_regular_quarters
		myQuarters = []
		Quarter.all.sort.each{|quarter|
			unless quarter.victims.empty?
				myQuarters.push(quarter)
			end
		}
		return myQuarters
	end

	def get_specific_quarters(years, unit)
		myQuarters = []
		years.each{|thisYear|
			year = Year.find(thisYear["id"])
			year.quarters.sort.each {|quarter|
			if  unit == "victims"
				unless quarter.victims.empty?
					myQuarters.push(quarter)
				end
			elsif unit == "detainees"
				unless quarter.detainees.empty?
					myQuarters.push(quarter)
				end
			end
			}
		}
		return myQuarters	
	end

	def get_specific_months(years, unit)
		myMonths = []
		years.each{|thisYear|
			year = Year.find(thisYear["id"])
			year.months.sort.each {|month|
			if  unit == "victims"
				unless month.victims.empty?
					myMonths.push(month)
				end
			elsif unit == "detainees"
				unless month.detainees.empty?
					myMonths.push(month)
				end
			end
			}
		}
		return myMonths	
	end

	def get_regular_months
		myMonths = []
		Month.all.sort.each{|month|
			unless month.victims.empty?
				myMonths.push(month)
			end
		}
		return myMonths
	end

	def get_months(year)
		myArr = []
		# target = Event.where(("CAST(strftime('%Y', event_date) as INT) = ?"), year)
		target = Event.where("extract(year from event_date) + 0 = ?", year)
		target = target.pluck(:event_date).uniq
		target = target.sort
		n = target.length - 1
		myRange = (1..n)
		myRange.each{|x|
			myMonth = target[x].strftime("%m")
			myArr.push(myMonth)
		}
		myMonths = myArr.uniq
		return	myMonths
	end

	def get_time_span(month,year)
		monthArr = ["04","06","09","11"]
		if month == ""
			time_span = (year+"-01-01"..year+"-12-31")
		elsif month == "02"
			time_span = (year+"-"+month+"-01"..year+"-"+month+"-28")
		elsif monthArr.include? month
			time_span = (year+"-"+month+"-01"..year+"-"+month+"-30")
		else
			time_span = (year+"-"+month+"-01"..year+"-"+month+"-31")	
		end
		return time_span
	end

	def admin_mail
		admin_mail = "roberto.valladarespiedras@gmail.com"
		return admin_mail
	end

	def root_path
		myPath = "/Users/bobsled/lantiamaster/"
		myLength = myPath.length
		return {:myPath=>myPath, :myLength=>myLength}
	end

	def define_query(myParams)

	 	# DEFINE GEOGRAPHIC SCOPE OF QUERY
	 	if myParams["county_id"] != "" && myParams["county_id"] != nil
	 		@county_query = true
	 		@my_county = County.where(:id=>myParams["county_id"]).last
	 	elsif myParams["state_id"] != ""
	 		@state_query = true
	 		@my_state = State.where(:id=>myParams["state_id"]).last
	 	elsif myParams["city_id"] != ""
	 		@city_query = true
	 		@my_city = City.where(:id=>myParams["city_id"]).last
	 	end

	 	# DEFINE QUERY TIMEFRAME
	 	if myParams["month"] != "" && myParams["month"] != nil
	 		date_query = true
	 		@month_query = true
	 		this_month = myParams["month"]
	 		@my_month = {"year"=>myParams["year"], "month"=>myParams["month"]}
	 		myDates = get_time_span(myParams["month"],myParams["year"])
	 	elsif myParams["year"] != "" && myParams["year"] != nil
	 		date_query = true
	 		@year_query = true
	 		@my_year = myParams["year"]
	 		myDates = get_time_span("",myParams["year"])
	 	end

	 	if myParams["killing_query_group"] == "for_killing"
	 		if @county_query
	 			geo_query = @my_county.killings
	 		elsif @state_query
	 			geo_query = @my_state.killings
	 		elsif @city_query
	 			geo_query = @my_city.killings
	 		else	
	 			geo_query = Killing.all
	 		end
	 		if date_query
	 			time_query = Killing.joins(:event).where(events: {:event_date=>myDates})
	 		else
	 			time_query = Killing.all
	 		end
	 		@myQuery = geo_query.merge(time_query)
	 		@myQuery = @myQuery.sort_by{|x| x.killed_count}.reverse
	 		@type_of_query = "Ejecuciones"

	 	elsif myParams["killing_query_group"] == "for_victim"	 		
	 		if @county_query
	 			geo_query = @my_county.victims
	 		elsif @state_query
	 			geo_query = @my_state.victims
	 		elsif @my_city
	 			geo_query = @my_city.victims
	 		else
	 			geo_query = Victim.all
	 		end
	 		if date_query
	 			time_query = Victim.joins(:killing=>[:event]).where(events: {:event_date=>myDates})
	 		else
	 			time_query = Victim.all
	 		end
	 		@myQuery = geo_query.merge(time_query)
	 		stretch1 = @myQuery.where.not(:legacy_name=>"")
	 		stretch1 = stretch1.sort_by{|x| x.legacy_name}
	 		stretch2 = @myQuery.where(:legacy_name=>"")
	 		@myQuery = stretch1 + stretch2
	 		@type_of_query = "Víctimas"

	 	elsif myParams["killing_query_group"] == "for_source"
	 		if @county_query
	 			geo_query = @my_county.sources
	 		elsif @state_query
	 			geo_query = @my_state.sources
	 		elsif @city_query
	 			geo_query = @my_city.sources
	 		else
	 			geo_query = Source.all
	 		end
	 		if date_query
	 			time_query = Source.joins(:events_sources=>[:event]).where(events: {:event_date=>myDates})
	 		else
	 			time_query = Source.all
	 		end
	 		@myQuery = geo_query.merge(time_query)
	 		@type_of_query = "Fuentes"
	 	end
	 	return	{:myQuery=>@myQuery, :type_of_query=>@type_of_query}
	end

	def header_and_cells

		myParams = session[:params]

		@header = []
 		@cells = {}

 		# VICTIM CELLS
 		if myParams["victim_name"]
 			@header.push("NOMBRE")
 			@cells["victim_name"] = true
 		end
 		if myParams["victim_alias"]
 			@header.push("ALIAS")
 			@cells["victim_alias"] = true
 		end
 		if myParams["victim_gender"]
 			@header.push("SEXO")
 			@cells["victim_gender"] = true
 		end
 		if myParams["victim_age"]
 			@header.push("EDAD")
 			@cells["victim_age"] = true
 		end
 		if myParams["victim_boolean"]
 			@header.push("CARACTERÍSTICAS VÍCTIMA")
 			@cells["victim_boolean"] = true
 		end


 		# SOURCE CELLS
 		if myParams["source_publication"]
 			@header.push("FECHA PUBLICACIÓN")
 			@cells["source_publication"] = true
 		end
 		if myParams["source_organization"]
 			@header.push("MEDIO/LINK")
 			@cells["source_organization"] = true
 		end
 		if myParams["source_member"]
 			@header.push("AUTOR")
 			@cells["source_member"] = true
 		end
 		if myParams["event_description"]
 			@header.push("DESCRIPCIÓN")
 			@cells["event_description"] = true
 		end

 		# STATE CELLS
 		if myParams["state_name"]
 			@header.push("NOMBRE ENTIDAD FEDERATIVA")
 			@cells["state_name"] = true
 		end
 		if myParams["state_acronym"]
 			@header.push("ABREVIATURA ENTIDAD FEDERATIVA")
 			@cells["state_acronym"] = true
 		end
 		if myParams["state_code"]
 			@header.push("CÓDIGO ENTIDAD FEDERATIVA")
 			@cells["state_code"] = true
 		end
 		if myParams["state_population"]
 			@header.push("POBLACIÓN ENTIDAD FEDERATIVA")
 			@cells["state_population"] = true
 		end
 		
 		# COUNTY CELLS
 		if myParams["city_name"]
 			@header.push("ZONA METROPOLITANA")
 			@cells["city_name"] = true
 		end
 		if myParams["county_name"]
 			@header.push("MUNICIPIO")
 			@cells["county_name"] = true
 		end
 		if myParams["county_full_code"]
			@header.push("CÓDIGO MUNICIPIO")
 			@cells["county_full_code"] = true
 		end
 		if myParams["county_population"]
			@header.push("CÓDIGO MUNICIPIO")
 			@cells["county_population"] = true
 		end

 		# EVENT/KILLING CELLS
 		if myParams["event_date"]
 			@header.push("FECHA EJECUCIÓN")
 			@cells["event_date"] = true
 		end
 		if myParams["killed_count"]
 			@header.push("NÚM MUERTOS EJECUCIÓN")
 			@cells["killed_count"] = true
 		end
 		if myParams["aggresor_count"]
 			@header.push("NÚM AGRESORES")
 			@cells["aggresor_count"] = true
 		end
 		if myParams["type_of_place"]
 			@header.push("TIPO DE LUGAR")
 			@cells["type_of_place"] = true
 		end
 		if myParams["killer_vehicle_count"]
 			@header.push("NÚM VEHÍCULOS")
 			@cells["killer_vehicle_count"] = true
 		end
 		if myParams["killing_boolean"]
 			@header.push("CARACTERÍSTICAS EJECUCIÓN")
 			@cells["killing_boolean"] = true
 		end
 		if myParams["event_sources"]
 			@header.push("FUENTES")
 			@cells["event_sources"] = true
 		end

 		return {:header=>@header, :cells=>@cells}
		
	end

	def cell_content(myType, cells, myObject)
		if myType == "Ejecuciones"
			content = killing_content(cells, myObject)
		elsif myType == "Víctimas"
			content = victim_content(cells, myObject)
		elsif myType == "Fuentes"
			content = source_content(cells, myObject)
		end
		return content
	end

	def killing_content(cells, myObject)
		contentArr = []
		myObject.each{|query|
			rowArr = []

			# STATE CELLS
			if cells["state_name"]
				rowArr.push(query.event.town.county.state.name)
			end
			if cells["state_acronym"]
				rowArr.push(query.event.town.county.state.shortname)
			end
			if cells["state_code"]
				rowArr.push(query.event.town.county.state.code)
			end
			if cells["state_population"]
				rowArr.push(number_with_delimiter(query.event.town.county.state.population))
			end

			# COUNTY CELLS
			if cells["city_name"]
				if query.event.town.county.city
					rowArr.push(query.event.town.county.city.name)
				else
					rowArr.push("--")
				end
			end
			if cells["county_name"]
				rowArr.push(query.event.town.county.name)
			end
			if cells["county_full_code"]
				rowArr.push(query.event.town.county.full_code)
			end
			if cells["county_population"]
				rowArr.push(number_with_delimiter(query.event.town.county.population))
			end

			# KILLING CELLS
			if cells["event_date"]
				rowArr.push(query.event.event_date.strftime("%d/%m/%Y"))
			end
			if cells["killed_count"]
				rowArr.push(query.killed_count)
			end
			if cells["aggresor_count"]
				rowArr.push(query.aggresor_count)
			end
			if cells["type_of_place"]
				rowArr.push(query.type_of_place)
			end
			if cells["killer_vehicle_count"]
				rowArr.push(query.killer_vehicle_count)
			end
			if cells["killing_boolean"]
				booleanString = ""
				if query.aggression
					booleanString << "-Fue agresión "
				end
				if query.shooting_among_criminals
					booleanString << "-Hubo enfrentamiento "
				end
				if query.shooting_between_criminals_and_authorities
					booleanString << "-Hubo enfrentamiento con autoridades "
				end
				if query.shooting_between_criminals_and_authorities
					booleanString << "- Hubo persecusión "
				end
				rowArr.push(booleanString)
			end
			if cells["event_sources"]
				sourceString = ""
				query.event.sources.each{|source|
					sourceString << source.url+" "
				}
				rowArr.push(sourceString)
			end
			contentArr.push(rowArr)
		}
		return contentArr
	end

	def indexLevels
		levelArr =[
			{:name=>"Crítico",:color=>"red",:score=>10, :hex=>"#f44336", :light_color=>"#fd5245", :floor=>65, :ceiling=>100},
			{:name=>"Alto",:color=>"orange",:score=>6.5, :hex=>"#ff9800", :light_color=>"#ffa31a", :floor=>45, :ceiling=>65},
			{:name=>"Medio",:color=>"yellow",:score=>5, :hex=>"#ffeb3b", :light_color=>"#ffec48", :floor=>25, :ceiling=>45},
			{:name=>"Bajo",:color=>"light-green",:score=>4, :hex=>"#8bc34a", :light_color=>"#99d159", :floor=>0, :ceiling=>25}
		]
		return levelArr	
	end

	def victim_content(cells, myObject)
		contentArr = []
		myObject.each{|query|
			rowArr = []


			# VICTIM CELLS
			if cells["victim_name"]
				rowArr.push(query.legacy_name)
			end	
			if cells["victim_alias"]
				rowArr.push(query.alias)
			end	
			if cells["victim_gender"]
				rowArr.push(query.gender)
			end	
			if cells["victim_age"]
				rowArr.push(query.age)
			end
			
			if cells["victim_boolean"]
				booleanString = ""
				if query.innocent_bystander
					booleanString << "-Daño colateral "
				end
				if query.reported_cartel_member
					booleanString << "-Probable miembro del crimen organizado " 
				end
				if query.agressor
					booleanString << "-Agresor " 
				end
				if query.acuchillado
					booleanString << "-Acuchillado " 
				end
				if query.a_golpes
					booleanString << "-A golpes " 
				end
				if query.asfixiado
					booleanString << "-Asfixiado " 
				end
				if query.baleado
					booleanString << "-Baleado " 
				end
				if query.con_tiro_de_gracia
					booleanString << "-Con tiro de gracia " 
				end
				if query.calcinado
					booleanString << "-Calcinado " 
				end
				if query.cinta_adhesiva_en_la_cabeza
					booleanString << "-Cinta adhesiva en la cabeza " 
				end
				if query.colgado
					booleanString << "-Colgado " 
				end
				if query.con_dedos_en_la_boca
					booleanString << "-Con dedos en la boca " 
				end
				if query.con_la_lengua_cortada
					booleanString << "-Con la lengua cortada " 
				end
				if query.con_mensaje_escrito
					booleanString << "-Con mensaje escrito " 
				end
				if query.con_mensaje_escrito_en_el_cuerpo
					booleanString << "-Con mensaje escrito en el cuerpo " 
				end
				if query.con_senales_de_tortura
					booleanString << "-Con señales de tortura " 
				end
				if query.crucificado
					booleanString << "-Crucificado " 
				end
				if query.decapitado_cabeza_sin_cuerpo
					booleanString << "-Decapitado cabeza sin cuerpo " 
				end
				if query.decapitado_cuerpo_sin_cabeza
					booleanString << "-Decapitado cuerpo sin cabeza " 
				end
				if query.degollado
					booleanString << "-Degollado " 
				end
				if query.descalzo
					booleanString << "-Descalzo " 
				end
				if query.descuartizado
					booleanString << "-Descuartizado " 
				end
				if query.desnudo
					booleanString << "-Desnudo " 
				end
				if query.disuelto_en_acido
					booleanString << "-Disuelto_en_acido " 
				end
				if query.encobijado
					booleanString << "-Encobijado " 
				end
				if query.enlonado
					booleanString << "-Enlonado " 
				end
				if query.enterrado
					booleanString << "-Enterrado " 
				end
				if query.esposado
					booleanString << "-Esposado " 
				end
				if query.extraccion_del_globo_ocular
					booleanString << "-Extraccion del globo ocular " 
				end
				if query.hincado
					booleanString << "-Hincado " 
				end
				if query.manos_atadas_al_frente
					booleanString << "-Manos atadas al frente " 
				end
				if query.manos_atadas_atras
					booleanString << "-Manos atadas atras " 
				end
				if query.mutilacion
					booleanString << "-Mutilacion " 
				end
				if query.mutilacion_de_genitales
					booleanString << "-Mutilacion de genitales " 
				end
				if query.mutilacion_de_otra_parte
					booleanString << "-Mutilacion de otra parte " 
				end
				if query.piedra_u_objeto_pesado
					booleanString << "-Piedra u objeto pesado " 
				end
				if query.pies_atados
					booleanString << "-Pies atados " 
				end
				if query.semidesnudo
					booleanString << "-Semidesnudo " 
				end
				if query.semienterrado
					booleanString << "-Semienterrado " 
				end
				rowArr.push(booleanString)
			end

			# STATE CELLS
			if cells["state_name"]
				rowArr.push(query.killing.event.town.county.state.name)
			end
			if cells["state_acronym"]
				rowArr.push(query.killing.event.town.county.state.shortname)
			end
			if cells["state_code"]
				rowArr.push(query.killing.event.town.county.state.code)
			end
			if cells["state_population"]
				rowArr.push(number_with_delimiter(query.killing.event.town.county.state.population))
			end

			# COUNTY CELLS
			if cells["city_name"]
				if query.killing.event.town.county.city
					rowArr.push(query.killing.event.town.county.city.name)
				else
					rowArr.push("--")
				end
			end
			if cells["county_name"]
				rowArr.push(query.killing.event.town.county.name)
			end
			if cells["county_full_code"]
				rowArr.push(query.killing.event.town.county.full_code)
			end
			if cells["county_population"]
				rowArr.push(number_with_delimiter(query.killing.event.town.county.population))
			end

			# KILLING CELLS
			if cells["event_date"]
				rowArr.push(query.killing.event.event_date.strftime("%d/%m/%Y"))
			end
			if cells["killed_count"]
				rowArr.push(query.killing.killed_count)
			end
			if cells["aggresor_count"]
				rowArr.push(query.killing.aggresor_count)
			end
			if cells["type_of_place"]
				rowArr.push(query.killing.type_of_place)
			end
			if cells["killer_vehicle_count"]
				rowArr.push(query.killing.killer_vehicle_count)
			end
			if cells["killing_boolean"]
				booleanString = ""
				if query.killing.aggression
					booleanString << "-Fue agresión "
				end
				if query.killing.shooting_among_criminals
					booleanString << "-Hubo enfrentamiento "
				end
				if query.killing.shooting_between_criminals_and_authorities
					booleanString << "-Hubo enfrentamiento con autoridades "
				end
				if query.killing.shooting_between_criminals_and_authorities
					booleanString << "- Hubo persecusión "
				end
				rowArr.push(booleanString)
			end
			if cells["event_sources"]
				sourceString = ""
				query.killing.event.sources.each{|source|
					sourceString << source.url+" "
				}
				rowArr.push(sourceString)
			end


			contentArr.push(rowArr)
		}
		return contentArr
	end

	def clear_session			
		if session[:years]
			session.delete(:years)
		end
		if session[:victim_freq_params]
			session.delete(:victim_freq_params)
		end
		if session[:checkedYearsArr]
			session.delete(:checkedYearsArr)
		end
		if session[:checkedStates]
			session.delete(:checkedStates)
		end
		if session[:checkedStatesArr]
			session.delete(:checkedStatesArr)
		end
		if session[:checkedCitiesArr]
			session.delete(:checkedCitiesArr)
		end
		if session[:checkedGenderOptions]
			session.delete(:checkedGenderOptions)
		end
		if session[:victim_freq_params]
			session.delete(:victim_freq_params)
		end
		if session[:checkedCounties]
			session.delete(:checkedCounties)
		end
		if session[:filename]
			session.delete(:filename)
		end
		if session[:detainee_freq_params]
			session.delete(:detainee_freq_params)
		end
		if session[:checkedOrganizations]
			session.delete(:checkedOrganizations)
		end
		if session[:checkedRoles]
			session.delete(:checkedRoles)
		end
		if session[:indexPage]
			session.delete(:indexPage)
		end
		if session[:destinations]
			session.delete(:destinations)
		end
	end

	def variable_change_and_icon(current_count, previous_count)
		changeHash = {}
		changeHash[:variation] = (((current_count - previous_count)/previous_count.to_f)*100).round(1)
		if changeHash[:variation] < 0
			changeHash[:icon] = "arrow_downward"
			changeHash[:color] = "light-green"
		elsif changeHash[:variation] == 0
			changeHash[:icon] = "drag_handle"
			changeHash[:color] = "grey"
		else
			changeHash[:icon] = "arrow_upward"
			changeHash[:color] = "red"	
		end
		changeHash[:variation] = changeHash[:variation].abs
		if previous_count == 0 && current_count != 0
			changeHash[:variation] = "N.A. "
		end
 		return changeHash
	end

  	def get_quarter_victims(quarter, localVictims)
  		periodVictims = quarter.victims
  		number_of_victims = localVictims.merge(periodVictims).length 
  		return number_of_victims
  	end

  	def bob_decode(myString)
  		spanish = {
  			"Á" => "A",
  			"á" => "a",
  			"É" => "E",
  			"é" => "e",
  			"Í" => "I",
  			"í" => "i",
  			"Ó" => "O",
  			"ó" => "o",
  			"ú" => "u",
  			"ü" => "u",
  			"ñ" => "n",
  		}
  		myString = myString.encode("ASCII", "UTF-8", fallback: spanish)
  		return myString
  	end

end
