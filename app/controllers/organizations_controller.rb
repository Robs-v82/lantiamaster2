class OrganizationsController < ApplicationController

	def password  
  	end

  	def main

  		@myYears = helpers.get_years
  		
  		@states = State.all

  		@cities = City.all.sort_by{|city|city.name}

  		@county_search_input = "query[county_id]"

  		session[:page] = nil
  		session[:params] = nil

  		@myQueries = [
  			{caption:"Ejecuciones", box_id:"killing_query_box", name:"for_killing"},
			{caption:"Víctimas", box_id:"victim_query_box", name:"for_victim"},
			# {caption:"Fuentes", box_id:"source_query_box", name:"for_source"},
  		]

  		@victim_checkboxes = [
  			{caption: "NOMBRE", name:"query[victim_name]"},
  			{caption: "ALIAS", name:"query[victim_alias]"},
  			{caption: "SEXO", name:"query[victim_gender]"},
  			{caption: "EDAD", name:"query[victim_age]"},
  			{caption: "CARACTERÍSTICAS", name:"query[victim_boolean]"},
  		]

  		@state_checkboxes = [
  			{caption: "NOMBRE", name:"query[state_name]"},
  			{caption: "ABREVIATURA", name:"query[state_acronym]"},
  			{caption: "CLAVE", name:"query[state_code]"},
  			{caption: "POBLACIÓN", name:"query[state_population]"},
  		]

  		@county_checkboxes = [
  			{caption: "NOMBRE", name:"query[county_name]"},
  			{caption: "CLAVE",  name:"query[county_full_code]"},
  			{caption: "POBLACIÓN", name:"query[county_population]"},
  			{caption: "Z. METRO.", name: "query[city_name]"},
  		]

  		@event_checkboxes = [
  			{caption: "FECHA", name:"query[event_date]"},
  			{caption: "FUENTES", name:"query[event_sources]"},
  			{caption: "# VÍCTIMAS", name:"query[killed_count]"},
  			{caption: "# AGRESORES", name:"query[aggresor_count]"},
  			{caption: "TIPO DE LUGAR", name:"query[type_of_place]"},
  			{caption: "ARMAS USADAS", name:"query[weapons]"},
  			{caption: "# VEHÍCULOS", name:"query[killer_vehicle_count]"},
  			{caption: "CARACTERÍSTICAS", name:"query[killing_boolean]"},

  		]

  		@source_checkboxes = [
  			{caption: "FECHA", name:"query[source_publication]"},
  			{caption: "MEDIO/LINK",  name:"query[source_organization]"},
  			{caption: "AUTOR", name:"query[source_member]"},
  			{caption: "INCIDENTES", name: "query[event_description]"},
  		]

  		@events = Event.all
  		@killings = Killing.all
  		@victims = Victim.all
  		@sources = Source.all
  		# @papers = Division.where(:scian3=>510).last.organizations
  	end

  	def login
	  	target_user = User.find_by_mail(password_params[:mail])
	    if target_user && target_user.authenticate(password_params[:password])
	      session[:user_id] = target_user[:id]
	      redirect_to '/intro'
	    else
	      redirect_to '/password'
	    end   
  	end

	def logout
		session[:user_id] = nil
		redirect_to '/password'
	end

	def banxico	
		@states = State.all
	end

	def lantia
		@states = State.all
	end

	def new
		@county_search_input = "organization"
		@organization_header = form_header("account_balance","Organización")
		@states = State.all
		@sectors = Sector.all.sort_by{|record| record.scian2}
		@organization_text_inputs = [
			{field_name: "name", caption: "NOMBRE", selector: "organization_name_selector"},
			{field_name: "legal_name", caption: "RAZÓN SOCIAL", selector: "organization_legal_name_selector"},
			{field_name: "rfc", caption: "RFC", selector: "organization_rfc_selector"},
			{field_name: "acronym", caption: "SIGLAS", selector: "organization_acronym_selector"},
		]
	end

	def create_organization
		myName = create_organization_params[:name]
		myrfc = create_organization_params[:rfc]
		myAcronym = create_organization_params[:acronym]
		myCounty = create_organization_params[:county_id]
		thisDivision = create_organization_params[:division_id]
		Organization.create(:name=>myName,:rfc=>myrfc,:acronym=>myAcronym,:county_id=>myCounty)
		myDivision = Division.find(thisDivision)
		targetOrganization = Organization.last
		targetOrganization.divisions << myDivision
		redirect_to "/organizations/new"
	end

	def getDivisions
	    targetSector = getDivisions_params[:sector_id].to_i
	    targetDivisions = Sector.find(targetSector).divisions
	    render json: {divisions: targetDivisions}			
	end


	def getMembers
	    targetOrganization = params[:organization_id].to_i
	    print ("***"*50)+targetOrganization.to_s+("***"*50)
	    targetMembers = Organization.find(targetOrganization).members
	   	print ("***"*50)+targetMembers.last.firstname+("***"*50)
	    render json: {members: targetMembers}		
	end

	private

	def password_params
		params.require(:user).permit(:mail, :password)
	end

	def create_organization_params
		params.require(:organization).permit(:name, :rfc, :acronym, :county_id, :division_id)
		
	end

	def getDivisions_params
    	params.require(:organization).permit(:sector_id)
  	end

  	def getMembers_params
  		params.require(:source).permit(:organization_id)
  	end

  	def getFields_params
  		params.require(:query).permit(:general)
  	end

end
