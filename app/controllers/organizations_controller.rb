class OrganizationsController < ApplicationController

	after_action :remove_password_error_message, only: [:password]

	def password
	    if session[:password_error]
      	@password_error = true
      	print "******PASSWORD ERROR!!!!!*******"
    end 
  	end

  	def main

  		@myYears = helpers.get_years
  		
  		@states = State.all.sort

  		@cities = City.all.sort_by{|city|city.name}

  		@county_search_input = "query[county_id]"

  		session[:page] = nil
  		session[:params] = nil

  		@myQueries = [
  			{caption:"Eventos", box_id:"killing_query_box", name:"for_killing"},
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
	      redirect_to '/datasets/victims_query'
	    else
	    	print "***************WRONG PASSWORD!!! "
	    	session[:password_error] = true
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
		@county_search_input = "query"
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
		Organization.last.avatar.attach(create_organization_params[:avatar])
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
	    targetMembers = Organization.find(targetOrganization).members
	    render json: {members: targetMembers}		
	end

	def dictionary
		organizationsHash = {}
		Organization.all.each{|x|
			myKey = x.name + "; " + x.subleague
			organizationsHash[myKey] = nil
		}
 		render json: organizationsHash
	end

	def load_organizations

		divisions = [
			{:slot=>9,:scian3=>981,:name=>"Narcotráfico"},
			{:slot=>10,:scian3=>982,:name=>"Narcomenudeo"},
			{:slot=>11,:scian3=>983,:name=>"Extorsión"},
			{:slot=>12,:scian3=>984,:name=>"Mercado Ilícito de Hidrocarburos"},
			{:slot=>13,:scian3=>985,:name=>"Trata y tráfico de personas"},
			{:slot=>14,:scian3=>986,:name=>"Tráfico de armas"},
			{:slot=>15,:scian3=>987,:name=>"Robo de ferrocarril"},
			{:slot=>16,:scian3=>988,:name=>"Robo de transportistas"},
			{:slot=>17,:scian3=>989,:name=>"Tala clandestina"},
			{:slot=>18,:scian3=>991,:name=>"Contrabando de mercancías"},
			{:slot=>19,:scian3=>992,:name=>"Lavado de dinero"},
			{:slot=>21,:scian3=>993,:name=>"Actos de terrorismo"}
		]

		myFile = load_organizations_params[:file]
		table = CSV.parse(File.read(myFile))

		table.each{|x|

		# CREATE ORGANIZATION IF IT DOES NOT EXIST
			if Organization.where(:name=>x[0].strip).empty?
				print "NEW ORGANIZATION :" + x[0]
				Organization.create(:name=>x[0].strip,:acronym=>x[2],:league=>x[3],:subleague=>x[4])
			end
		}

		 
		table.each{|x|

		# UPDATE DIVIDIONS
			targetOrganization = Organization.where(:name=>x[0].strip).last
			divisions.each{|y|
				myDivision = Division.where(:scian3=>y[:scian3]).last
				if x[y[:slot]] == "1"
					print "ACITVITY HIT!!!"
					targetOrganization.divisions << myDivision
				end
			}

		# UPDATE PARENT ORIGIN ALLIES AND RIVALS
			targetOrganization = Organization.where(:name=>x[0].strip).last
			unless x[1].nil?
				myNames = x[1].split(";")
				cleanNames = []
				myNames.each {|myName|
					myName = myName.strip
					cleanNames.push(myName)
				}
				targetOrganization.update(:alias=>cleanNames)
			end	
			unless x[5].nil?
				unless Organization.where(:name=>x[5]).empty?
					parentOrganization = Organization.where(:name=>x[5]).last
					targetOrganization.update(:parent_id=>parentOrganization.id)
				end
			end
			unless x[6].nil?
				x[6].split(";").each{|org|
					myOrigins = []
					unless Organization.where(:name=>org).empty?
						originOrganization = Organization.where(:name=>org).last
						myOrigins.push(originOrganization.id)
					end	
					targetOrganization.update(:origin=>myOrigins)	
				}
			end	
			unless x[7].nil?
				x[7].split(";").each{|org|
					myAllies = []
					unless Organization.where(:name=>org).empty?
						alliedOrganization = Organization.where(:name=>org).last
						myAllies.push(alliedOrganization.id)
					end	
					targetOrganization.update(:allies=>myAllies)	
				}
			end	
			unless x[8].nil?
				x[8].split(";").each{|org|
					myRivals = []
					unless Organization.where(:name=>org).empty?
						rivalOrganization = Organization.where(:name=>org).last
						myRivals.push(rivalOrganization.id)
					end
					targetOrganization.update(:rivals=>myRivals)	
				}
			end	
		}
		session[:filename] = load_organizations_params[:file].original_filename
		session[:load_success] = true

		redirect_to "/datasets/load"
	end

	def load_organization_events

		myCategories = [
			"Decomiso",
			"Desmantelamiento de narcolaboratorio",
			"Desplazamiento",
			"Narcomensaje",
			"Entrega de despensas",
			"Informe de inteligencia",
			"Investigación periodística",
			"Solicitud de información"
		]


		myFile = load_organization_events_params[:file]
		table = CSV.parse(File.read(myFile))

		table.each{|x|
			if Lead.where(:legacy_id=>x[0]).empty?
				if myCategories.include? x[9]
					unless Organization.where(:name=>x[3]).empty?
						myOrganization = Organization.where(:name=>x[3]).last.id
						myString = x[10][6..-1]+"_"+x[10][3,2]
						print "*************MONTH NAME: "
						print myString
						myMonth =  Month.where(:name=>myString).last.id
						unless x[2].nil? 
							towns = []
							townArr = x[2].split(";")
							townArr.each{|townName|
								unless County.where(:full_code=>x[1]).last.towns.where(:name=>townName).empty?
									thisTown = County.where(:full_code=>x[1]).last.towns.where(:name=>townName).last.full_code
									towns.push(thisTown)
								else
									towns.push(x[1]+"0000")
								end
								towns = towns.uniq
							}
						else
							towns = [x[1]+"0000"]
						end
						towns.each{|town|
							myTown = Town.where(:full_code=>town).last.id
							# ADD EVENT AND SOURCES
							Event.create(:organization_id=>myOrganization, :town_id=>myTown, :event_date=>x[10], :month_id=>myMonth)
							(11..15).each{|y|
								Source.create(:url=>x[y])
								mySource = Source.last
								Event.last.sources << mySource
							}

							# ADD LEAD
							myEvent = Event.last.id
							Lead.create(:legacy_id=>x[0], :category=>x[9], :event_id=>myEvent)	
						}
						
						# ADD MEMBERS
						 
						if Organization.where(:name=>x[3]).last.members.where(:firstname=>x[5],:lastname1=>x[6],:lastname2=>x[7]).empty?
							unless x[5].nil? && x[8].nil?
								myAlias = x[8].split(";")
								Member.create(:organization_id=>myOrganization,:firstname=>x[5],:lastname1=>x[6],:lastname2=>x[7], :alias=>myAlias)
							end
						end
					end
				end		
			end
		}

		session[:filename] = load_organization_events_params[:file].original_filename
		session[:load_success] = true

		redirect_to "/datasets/load"
		
	end

	private

	def load_organizations_params
		params.require(:query).permit(:file)
	end

	def load_organization_events_params
		params.require(:query).permit(:file)
	end

	def password_params
		params.require(:user).permit(:mail, :password)
	end

	def create_organization_params
		params.require(:organization).permit(:name, :rfc, :acronym, :county_id, :division_id, :avatar)
		
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
