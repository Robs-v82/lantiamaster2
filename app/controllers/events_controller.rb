class EventsController < ApplicationController

	def killings
		@states = State.all
		@source_counter = State.find(1,2)
		@media_sites = Division.where(:scian3=>510).last.organizations.uniq.sort_by{|organization|organization.name}
		@town_focus_model
		@my_input_name = "event[town_id]"
		@killing_count_variables = [
			{field_name: "killed_count", caption: "NÚM. EJECUTADOS"},
			{field_name: "wounded_count", caption: "NÚM. HERIDOS"},
			{field_name: "killers_count", caption: "NÚM. EJECUTADORES"},
			{field_name: "arrested_count", caption: "NÚM. ARRESTADOS"},
		]
		@killing_boolean_variables = [
			{field_name: "aggression", caption: "AGRESIÓN"},
			{field_name: "shooting_between_criminals_and_authorities", caption: "ENFRENTAMIENTO DO Y AUT"},
			{field_name: "corpse", caption: "HALLAZGO CUERPOS"},
			{field_name: "mass_grave", caption: "HALLAZGO FOSA"},
			{field_name: "white_weapon", caption: "ARMA BLANCA"},
			{field_name: "fire_weapon", caption: "ARMA DE FUEGO"},
		]
		@killing_header = form_header("priority_high","Ejecución")
		@myTypes = type_of_place
	end

	def create_killing
		myDateTime = event_params[:date] + event_params[:time]
		myCount = killing_params[:killed_count]
		session[:current_killed_count] = myCount
		
		# CREATE EVENT AND GET ID
		Event.create(:event_date=>myDateTime,
			:town_id=>event_params[:town_id]
			)
		myEventId = Event.last.id
		killing_params[:event_id] = myEventId

		# CREATE AND LINK THE SOURCES
		Source.create(source1_params)
		mySource = Source.last
		Event.last.sources << mySource
		Source.create(source2_params)
		mySource = Source.last
		Event.last.sources << mySource
		
		# CREATE THE KILLING
		Killing.create(:event_id=>myEventId)
		Killing.last.update(killing_params)
		session[:current_killing_id] = Killing.last.id
		redirect_to "/events/victims/#{myCount}"
	end

	def victims
		@myCount = params[:killed_count].to_i
		@killing_header = form_header("person","Víctima")
		@victim_text_inputs = [
			{field_name: "firstname", caption: "NOMBRE(S)", selector: "victim_firsname_selector"},
			{field_name: "lastname1", caption: "PRIMER APELLIDO", selector: "victim_lastname1_selector"},
			{field_name: "lastname2", caption: "SEGUNDO APELLIDO", selector: "victim_lastname2_selector"},
			{field_name: "alias", caption: "ALIAS", selector: "victim_alias_selector"},
		]
		@victim_count_inputs = [
			{field_name: "age", caption: "EDAD", selector: "victim_age_selector", max: 99},
			{field_name: "age_in_months", caption: "EDAD (MESES)", selector: "victim_age_in_months_selector", max: 11}
		]
		@organizations = Organization.all
		@roles = hard_roles 
		myArr = ["acuchillado","a_golpes","asfixiado","baleado","con_tiro_de_gracia","calcinado","cinta_adhesiva_en_la_cabeza","colgado","con_dedos_en_la_boca","con_la_lengua_cortada","con_mensaje_escrito","con_mensaje_escrito_en_el_cuerpo","con_senales_de_tortura","crucificado","decapitado_cabeza_sin_cuerpo","decapitado_cuerpo_sin_cabeza","degollado","descalzo","descuartizado","desnudo","disuelto_en_acido","embolsado","encobijado","enlonado","enterrado","esposado","extraccion_del_globo_ocular","hincado","manos_atadas_al_frente","manos_atadas_atras","mutilacion","mutilacion_de_genitales","mutilacion_de_otra_parte","piedra_u_objeto_pesado","pies_atados","semidesnudo","semienterrado"]
		newArr = []
		myArr.each{|myString|
			if myString.include?("_")
				newHash={:field_name=>myString,:caption=>myString.upcase.tr!('_',' ')}
			else
				newHash={:field_name=>myString,:caption=>myString.upcase}
			end
			newArr.push(newHash)
		}
		@victim_boolean_inputs = newArr
		@victim_key_boolean_inputs = [
			{field_name: "innocent_bystander", caption: "VÍCTIMA COLATERAL", selector: "victim_innocent_bystander_selector"},
			{field_name: "agressor", caption: "IDENTIFICADO COMO AGRESOR", selector: "victim_aggressor_selector"}
		]
	end

	def create_victims
		params.each{|victim|
			print victim
			unless ["authenticity_token", "controller", "action"].include? victim[0]
				myVictim = victim[1]
				victimHash = Hash.new
				victimHash[:killing_id] = session[:current_killing_id]

				# @victim_text_inputs
				victimHash[:firstname] = myVictim[:firstname]
				victimHash[:lastname1] = myVictim[:lastname1]
				victimHash[:lastname2] = myVictim[:lastname2]
				victimHash[:alias] = myVictim[:alias]

				# @victim_count_inputs
				victimHash[:age] = myVictim[:age]
				victimHash[:age_in_months] = myVictim[:age_in_months]
				victimHash[:gender] = myVictim[:gender]
				victimHash[:organization_id] = myVictim[:organization_id]
				victimHash[:role_id] = myVictim[:role_id]

				# @victim_key_boolean_inputs
				victimHash[:innocent_bystander] = myVictim[:innocent_bystander]
				victimHash[:agressor] = myVictim[:agressor]

				# @victim_boolean_inputs
				victimHash[:acuchillado] = myVictim[:acuchillado]
				victimHash[:a_golpes] = myVictim[:a_golpes]
				victimHash[:asfixiado] = myVictim[:asfixiado]
				victimHash[:baleado] = myVictim[:baleado]
				victimHash[:con_tiro_de_gracia] = myVictim[:con_tiro_de_gracia]
				victimHash[:calcinado] = myVictim[:calcinado]
				victimHash[:cinta_adhesiva_en_la_cabeza] = myVictim[:cinta_adhesiva_en_la_cabeza]
				victimHash[:colgado] = myVictim[:colgado]
				victimHash[:con_dedos_en_la_boca] = myVictim[:con_dedos_en_la_boca]
				victimHash[:con_la_lengua_cortada] = myVictim[:con_la_lengua_cortada]
				victimHash[:con_mensaje_escrito] = myVictim[:con_mensaje_escrito]
				victimHash[:con_mensaje_escrito_en_el_cuerpo] = myVictim[:con_mensaje_escrito_en_el_cuerpo]
				victimHash[:con_senales_de_tortura] = myVictim[:con_senales_de_tortura]
				victimHash[:crucificado] = myVictim[:crucificado]
				victimHash[:decapitado_cabeza_sin_cuerpo] = myVictim[:decapitado_cabeza_sin_cuerpo]
				victimHash[:decapitado_cuerpo_sin_cabeza] = myVictim[:decapitado_cuerpo_sin_cabeza]
				victimHash[:degollado] = myVictim[:degollado]
				victimHash[:descalzo] = myVictim[:descalzo]
				victimHash[:descuartizado] = myVictim[:descuartizado]
				victimHash[:desnudo] = myVictim[:desnudo]
				victimHash[:disuelto_en_acido] = myVictim[:disuelto_en_acido]
				victimHash[:embolsado] = myVictim[:embolsado]
				victimHash[:encobijado] = myVictim[:encobijado]
				victimHash[:enterrado] = myVictim[:enterrado]
				victimHash[:extraccion_del_globo_ocular] = myVictim[:extraccion_del_globo_ocular]
				victimHash[:manos_atadas_al_frente] = myVictim[:manos_atadas_al_frente]
				victimHash[:manos_atadas_atras] = myVictim[:manos_atadas_atras]
				victimHash[:mutilacion] = myVictim[:mutilacion]
				victimHash[:mutilacion_de_genitales] = myVictim[:mutilacion_de_genitales]
				victimHash[:mutilacion_de_otra_parte] = myVictim[:mutilacion_de_otra_parte]
				victimHash[:piedra_u_objeto_pesado] = myVictim[:piedra_u_objeto_pesado]
				victimHash[:pies_atados] = myVictim[:pies_atados]
				victimHash[:semidesnudo] = myVictim[:semidesnudo]
				victimHash[:semienterrado] = myVictim[:semienterrado]

				Victim.create(victimHash)
			end
		}
		redirect_to '/events/killings'
	end

	def create_single_victim
		x = session[:current_killed_count].to_i
		my_victim_params = single_victim_params
		my_victim_params[:killing_id] = session[:current_killing_id]
		(1..x).each{
			Victim.create(my_victim_params)
		}
		redirect_to '/events/killings'
	end

	def send_query

		@page_scope = 20
		if session[:page] == nil
			session[:page] = 1			
		end

		if session[:params]
			myParams = session[:params]
		else
			myParams = query_params
			session[:params] = myParams
		end 

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
	 		myDates = helpers.get_time_span(myParams["month"],myParams["year"])
	 	elsif myParams["year"] != "" && myParams["year"] != nil
	 		date_query = true
	 		@year_query = true
	 		@my_year = myParams["year"]
	 		myDates = helpers.get_time_span("",myParams["year"])
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

	 	# MANAGE PAGES AND PAGE SCOPE
	 	@data_length = @myQuery.length
	 	if session[:page] >= (@data_length/@page_scope.to_f).ceil
	 		@finalPage = true
	 	end
	 	if session[:page] > @data_length/@page_scope
	 		@end = @data_length
	 	else
	 		@end = @page_scope * session[:page]
	 	end
	 	@beginning = 1+((session[:page]-1)*@page_scope)
 		@myQuery = @myQuery[@beginning - 1, @page_scope]
 		
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
	end	

	def pageback
		session[:page] -= 1
		redirect_to '/send_query'
	end

	def pageforward
		session[:page] += 1
		redirect_to '/send_query'
	end

	private

	def event_params
      params.require(:event).permit(:date, :time, :town_id)
    end

    def killing_params
      params.require(:killing).permit(:killed_count, :wounded_count, :killers_count, :arrested_count, :type_of_place, :mass_grave, :fire_weapon, :white_weapon, :aggression, :shooting_between_criminals_and_authorities, :notes)
    end

    def source1_params
    	params.require(:source1).permit(:publication, :url, :member_id)
    end

    def source2_params
    	params.require(:source2).permit(:publication, :url, :member_id)
    end

	def single_victim_params
		params.require(:victim).permit(:firstname, :lastname1, :lastname2, :alias, :gender, :age, :age_in_months, :innocent_bystander, :reported_cartel_member, :agressor, :acuchillado, :a_golpes, :asfixiado, :baleado, :con_tiro_de_gracia, :calcinado, :cinta_adhesiva_en_la_cabeza, :colgado, :con_dedos_en_la_boca, :con_la_lengua_cortada, :con_mensaje_escrito, :con_mensaje_escrito_en_el_cuerpo, :con_senales_de_tortura, :crucificado, :decapitado_cabeza_sin_cuerpo, :decapitado_cuerpo_sin_cabeza, :degollado, :descalzo, :descuartizado, :desnudo, :disuelto_en_acido, :embolsado, :encobijado, :enlonado, :enterrado, :esposado, :extraccion_del_globo_ocular, :hincado, :manos_atadas_al_frente, :manos_atadas_atras, :mutilacion, :mutilacion_de_genitales, :mutilacion_de_otra_parte, :piedra_u_objeto_pesado, :pies_atados, :semidesnudo, :semienterrado, :otra_forma, :killing_id, :role_id, :organization_id)
	end

	def query_params
		params.require(:query).permit(:killing_query_group, :state_name,:state_acronym,:state_code,:state_population,:county_name,:county_full_code,:county_population,:city_name,:event_date,:time,:event_sources,:killed_count,:aggresor_count,:type_of_place,:weapons,:killer_vehicle_count,:killing_boolean, :victim_name, :victim_alias, :victim_gender, :victim_age, :victim_boolean, :source_publication, :source_organization, :source_member, :event_description, :state_id, :county_id, :city_id, :year, :month)
	end

end

