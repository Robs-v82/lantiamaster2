class MembersController < ApplicationController
	
	require 'pp'

	def detentions
		myFile = detention_params[:file]
		table = CSV.parse(File.read(myFile))
		mockOrganizations = [
			{:acronym=>"CJNG", :name=>"Cártel Jalisco Nueva Generación"},
			{:acronym=>"CDP", :name=>"Cártel de Sinaloa"},
			{:acronym=>"CDN", :name=>"Cártel del Noreste"},
			{:acronym=>"UT", :name=>"La Unión Tepito"}
		]

		table.each{|x|
			x = x.collect{ |e| e ? e.strip : e}
			
			#Check that organization exists
			if x[10].nil?
				orgString = nil
				mockOrganizations.each{|m|
					if x[9] == m[:acronym]
						orgString = m[:name]
					end	
				}
			else
				if x[10].include? " ("
					orgString = x[10].split(" (").first
				else
					orgString = x[10]
				end
			end
			targetOrganization = Organization.where(:name=>orgString).last
			if targetOrganization
				unless x[8].nil?

					# CREATE EVENT AND DETENTION IF THEY DO NOT EXIST
					if Detention.where(:legacy_id=>x[0]).empty?
						myCode = helpers.zero_padded_full_code(x[5])
						targetCounty = County.where(:full_code=>myCode).last
						countyPolice = targetCounty.organizations.where(:league=>"Seguridad Pública").last.name
						targetState = targetCounty.state
						statePolice = targetState.counties.where(:name=>"Sin definir").last.organizations.where(:league=>"Seguridad Pública").last.name
						stateAttorney = targetState.counties.where(:name=>"Sin definir").last.organizations.where(:league=>"Procuración de Justicia").last.name
						targetTown = targetCounty.towns.where(:name=>"Sin definir").last
						myDate = "20"+x[3]+"-"+x[2]+"-"+x[1]
						myDate = myDate.to_datetime
						monthName = myDate.strftime("%Y")+"_"+myDate.strftime("%m")
						targetMonth = Month.where(:name=>monthName).last
						Event.create(:event_date=>myDate, :town_id=>targetTown.id, :month_id=>targetMonth.id)
						targetEvent = Event.last
						limit = x.length-1
						(28..limit).each{|y|
							unless x[y].nil?
								if Source.where(:url=>x[y]).empty?
									Source.create(:url=>x[y])
									mySource = Source.last
								else
									mySource = Source.where(:url=>x[y]).last
								end
								unless targetEvent.sources.include? (mySource)
									targetEvent.sources << mySource
								end
							end
						}
						Detention.create(:event_id=>targetEvent.id,:legacy_id=>x[0])
						targetDetention = Detention.last

						# ADD AUTHORITIES
						policeArr = [
							{:name=>"Secretaría de la Defensa Nacional" , :slot=>19},
							{:name=>"Secretaría de Marina", :slot=>20},
							{:name=>"Guardia Nacional", :slot=>21},
							# {:name=>"Policía Federal", :slot=>22},
							{:name=>"Fiscalía General de la República", :slot=>23},
							{:name=>statePolice, :slot=>24},
							{:name=>stateAttorney, :slot=>25},
							{:name=>countyPolice, :slot=>26}
						]
						
						policeArr.each{|z|
							if x[z[:slot]] == "1"
								authority = Organization.where(:name=>z[:name]).last
								unless targetDetention.organizations.include? (authority)
									targetDetention.organizations << authority
								end
							end
						}

					else
						targetDetention = Detention.where(:legacy_id=>x[0]).last
					end

					# DEFINE ROLE
					unless Role.where(:name=>x[18]).empty?
						targetRole = Role.where(:name=>x[18]).last
					else
						targetRole = nil
					end

					# ADD DATEAINEES
					if x[8] == "1"
						if x[11].nil? && x[14].nil?
							Member.create(:organization_id=>targetOrganization.id)
							targetMember = Member.last	
						else
							myAlias = nil
							unless x[14].nil?
								myAlias = x[14].split(";")
							end
							Member.create(:organization_id=>targetOrganization.id,:firstname=>x[11],:lastname1=>x[12],:lastname2=>x[13], :alias=>myAlias)
							targetMember = Member.last
							targetMember = targetOrganization.members.where(:firstname=>x[11],:lastname1=>x[12],:lastname2=>x[13]).last
							targetMember.update(:detention_id=>targetDetention.id)
						end
						targetMember.update(:role_id=>targetRole.id)
						if x[15] == "M"
							targetMember.update(:gender=>"Masculino")
						elsif x[15] = "F"
							targetMember.update(:gender=>"Femenino")
						else	
							targetMember.update(:gender=>"No identificado")	
						end
					else
						(1..x[8].to_i).each{
							Member.create(:organization_id=>targetOrganization.id,:detention_id=>targetDetention.id)
							if targetRole
								Member.last.update(:role_id=>targetRole.id)
							end
							if x[15] == "M"
								Member.last.update(:gender=>"Masculino")
							elsif x[15] = "F"
								Member.last.update(:gender=>"Femenino")
							else	
								Member.last.update(:gender=>"No identificado")	
							end
						}
					end		
				end
			end	
		}
		session[:filename] = detention_params[:file].original_filename
		session[:load_success] = true
		redirect_to "/datasets/load"	
	end

	def detainees_query
		helpers.clear_session
		organizationOptions = helpers.get_detainees_cartels
		roleOptions = []
		myRoles = Role.where(:criminal=>true)
		myRoles.each{|role|
			roleOptions.push(role.id.to_s)
		} 
		session[:checkedStates] = false
		session[:checkedOrganizations] = false
		session[:checkedRoles] = false
		session[:detainee_freq_params] = ["quarterly","nationWise","organizationSplit", "noRoleSplit", organizationOptions, false, false, roleOptions]
		redirect_to "/members/detainees"
	end

	def post_detainees_query
		if detainee_freq_params[:freq_timeframe]
			session[:detainee_freq_params][0] = detainee_freq_params[:freq_timeframe]
		end
		if detainee_freq_params[:freq_placeframe]
			session[:detainee_freq_params][1] = detainee_freq_params[:freq_placeframe]
		end
		if detainee_freq_params[:freq_organizationframe]
			session[:detainee_freq_params][2] = detainee_freq_params[:freq_organizationframe]
		end
		if detainee_freq_params[:freq_roleframe]
			session[:detainee_freq_params][3] = detainee_freq_params[:freq_roleframe]
		end
		if detainee_freq_params[:freq_organizations]
			session[:detainee_freq_params][4] = detainee_freq_params[:freq_organizations]
		end
		if detainee_freq_params[:freq_states]
			myArr = detainee_freq_params[:freq_states].map(&:to_i)
			Cookie.create(:data=>myArr)
			session[:checkedStates] = Cookie.last.id
		end
		if detainee_freq_params[:freq_organizations]
			session[:detainee_freq_params][6] = detainee_freq_params[:freq_organizations]
			session[:checkedOrganizations] = session[:detainee_freq_params][6]
		end
		if detainee_freq_params[:freq_roles]
			session[:detainee_freq_params][7] = detainee_freq_params[:freq_roles]
			session[:checkedRoles] = session[:detainee_freq_params][7]
		end
		redirect_to "/members/detainees"
	end

	def detainees
		@key = Rails.application.credentials.google_maps_api_key
				print "*********"*100
				print session[:detainee_freq_params]
		@my_freq_table = detainee_freq_table(
			session[:detainee_freq_params][0],
			session[:detainee_freq_params][1],
			session[:detainee_freq_params][2],
			session[:detainee_freq_params][3],
			session[:detainee_freq_params][4],
			session[:checkedStates],
			session[:detainee_freq_params][6],
			session[:detainee_freq_params][7]
		)
		@timeFrames = [
			{caption:"Trimestral", box_id:"quarterly_query_box", name:"quarterly"},
			{caption:"Mensual", box_id:"monthly_query_box", name:"monthly"},
  		]
  		@organizationFrames = [
  			{caption:"No desagregar", box_id:"no_organization_split_query_box", name:"noOrganizationSplit"},
			{caption:"Desagregar", box_id:"organization_split_query_box", name:"organizationSplit"},
  		]
   		@roleFrames = [
  			{caption:"No desagregar", box_id:"no_role_split_query_box", name:"noRoleSplit"},
			{caption:"Desagregar", box_id:"role_split_query_box", name:"roleSplit"}, 
  		]
  		@placeFrames = [
  			{caption:"Nacional", box_id:"nation_query_box", name:"nationWise"},
  			{caption:"Estado", box_id:"state_query_box", name:"stateWise"},
  		]
  		if session[:detainee_freq_params][0] == "quarterly"
  			@timeFrames[0][:checked] = true
  			@quarterly = true
  		else
  			@timeFrames[1][:checked] = true
  		end

  		if session[:detainee_freq_params][2] == "noOrganizationSplit"
  			@organizationFrames[0][:checked] = true
  		else
  			@organizationFrames[1][:checked] = true
  		end

  		if session[:detainee_freq_params][3] == "noRoleSplit"
  			@roleFrames[0][:checked] = true
  		else
  			@roleFrames[1][:checked] = true
  		end

  		if session[:detainee_freq_params][1] == "nationWise"
  			@nationWise = true
  			@placeFrames[0][:checked] = true
  		else
  			@stateWise = true
  			@placeFrames[1][:checked] = true
  		end

		@sortCounter = 0
		@states = State.all.sort
		if session[:checkedStates]
			@checkedStates = Cookie.find(session[:checkedStates]).data
		else
			@checkedStates = State.pluck(:id)
		end

		@organizations = helpers.get_detainees_cartels
		if session[:checkedOrganizations]
			@checkedOrganizations = session[:detainee_freq_params][6]
		else
			@checkedOrganizations = helpers.get_detainees_cartels
		end

		@roles = Role.where(:criminal=>true)
		if session[:checkedRoles]
			@checkedRoles = session[:checkedRoles]
		else
			roleOptions = []
			myRoles = Role.where(:criminal=>true)
			myRoles.each{|role|
				roleOptions.push(role.id.to_s)
			} 
			@checkedRoles = roleOptions
		end

		if @stateWise
			if @organizationFrames[0][:checked] && @roleFrames[0][:checked]
				@maps = true
			elsif @roleFrames[0][:checked] && @checkedOrganizations.length == 1
				@maps = true
			elsif @organizationFrames[0][:checked] && @checkedRoles.length == 1
				@maps = true
			elsif @checkedOrganizations.length == 1 && @checkedRoles.length == 1
				@maps = true
			end
		end

		print "*******"
		print session
	end

	def detainee_freq_table(period, scope, organization, role, organizationOptions, states, organizations, roleOptions)

		myTable = []
		headerHash = {}
		totalHash = {}
		totalHash[:name] = "Total"		

		years = Year.all
		if period == "quarterly"
			myPeriod = helpers.get_specific_quarters(years, "detainees")
		else
			myPeriod = helpers.get_specific_months(years, "detainees")
		end



		if scope == "nationWise"
			myScope = nil
		elsif scope == "stateWise"
			headerHash[:scope] = "ESTADO"
			if states == false
				myStates = State.all.sort			
			else
				myStates = []
				myKeys = Cookie.find(states).data
				myKeys.each {|x|
					myState = State.find(x)
					myStates.push(myState)
				}
				myScope = myStates	
			end
		end

		totalFreq = []
		(1..myPeriod.length).each {
			totalFreq.push(0)
		}

		headerHash[:period] = myPeriod

		myRoles = [] 
		roleOptions.each{|option|
			key = option.to_i
			myRole = Role.find(key)
			myRoles.push(myRole)
		}

		if myScope == nil
			if role == "noRoleSplit"
				if organization == "noOrganizationSplit"
					myTable.push(headerHash)
					placeHash = {}
					placeHash[:name] = "Nacional"
					freq = []
					counter = 0
					place_total = 0
					myPeriod.each {|timeUnit|
						number_of_detainees = timeUnit.detainees.length
						freq.push(number_of_detainees)
						totalFreq[counter] += number_of_detainees
						counter += 1
						place_total += number_of_detainees
					}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total 
					myTable.push(placeHash)
				else
					headerHash[:organization] = "ORGANIZACIÓN"
					totalHash[:organization_placer] = "--"
					myTable.push(headerHash)
					organizationOptions.each{|organization|
						placeHash = {}
						targetOrganization = Organization.where(:name=>organization).last
						placeHash[:organization] = organization
						placeHash[:name] = "Nacional"
						freq = []
						counter = 0
						place_total = 0
						myPeriod.each {|timeUnit|
							number_of_detainees = timeUnit.detainees.where(:organization_id=>targetOrganization.id).length
							freq.push(number_of_detainees)
							totalFreq[counter] += number_of_detainees
							counter += 1
							place_total += number_of_detainees
						}
						placeHash[:freq] = freq
						placeHash[:place_total] = place_total 
						myTable.push(placeHash)
					}
				end
			else
				headerHash[:role] = "POSICIÓN"
				totalHash[:role_placer] = "--"
				if organization == "noOrganizationSplit"
					myTable.push(headerHash)
					myRoles.each{|r|
						placeHash = {}
						placeHash[:name] = "Nacional"
						placeHash[:role] = r.name
						freq = []
						counter = 0
						place_total = 0
						roleDetainees = r.members
						myPeriod.each {|timeUnit|
							number_of_detainees = roleDetainees.merge(timeUnit.detainees).length
							freq.push(number_of_detainees)
							totalFreq[counter] += number_of_detainees
							counter += 1
							place_total += number_of_detainees
						}
						placeHash[:freq] = freq
						placeHash[:place_total] = place_total 
						myTable.push(placeHash)
					}
				else
					headerHash[:organization] = "ORGANIZACIÓN"
					totalHash[:organization_placer] = "--"
					myTable.push(headerHash)
					organizationOptions.each{|organization|
						myRoles.each{|r|
							placeHash = {}
							targetOrganization = Organization.where(:name=>organization).last
							placeHash[:organization] = organization
							placeHash[:name] = "Nacional"
							placeHash[:role] = r.name
							freq = []
							counter = 0
							place_total = 0
							roleDetainees = r.members
							myPeriod.each {|timeUnit|
								number_of_detainees = roleDetainees.merge(timeUnit.detainees.where(:organization_id=>targetOrganization.id)).length
								freq.push(number_of_detainees)
								totalFreq[counter] += number_of_detainees
								counter += 1
								place_total += number_of_detainees
							}
							placeHash[:freq] = freq
							placeHash[:place_total] = place_total 
							myTable.push(placeHash)
						}
					}
				end		
			end
		else
			if organization == "noOrganizationSplit"
				myTable.push(headerHash)
				myScope.each{|place|
					placeHash = {}
					placeHash[:name] = place.name
					freq = []
					counter = 0
					place_total = 0
					localDetainees = place.detainees
					myPeriod.each {|timeUnit|
						number_of_detainees = localDetainees.merge(timeUnit.detainees).length
						freq.push(number_of_detainees)
						totalFreq[counter] += number_of_detainees
						counter += 1
						place_total += number_of_detainees
					}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total 
					myTable.push(placeHash)
				}
			else
				headerHash[:organization] = "ORGANIZACIÓN"
				totalHash[:organization_placer] = "--"
				myTable.push(headerHash)
				myScope.each{|place|
					organizationOptions.each{|organization|
						placeHash = {}
						placeHash[:name] = place.name
						targetOrganization = Organization.where(:name=>organization).last
						placeHash[:organization] = organization
						freq = []
						counter = 0
						place_total = 0
						localDetainees = place.detainees
						myPeriod.each {|timeUnit|
							number_of_detainees = localDetainees.where(:organization_id=>targetOrganization.id).merge(timeUnit.detainees).length
							freq.push(number_of_detainees)
							totalFreq[counter] += number_of_detainees
							counter += 1
							place_total += number_of_detainees
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
		print "***********TABLE: "
		pp myTable

	end

	private

	def detention_params
		params.require(:query).permit(:file)
	end

	def detainee_freq_params
		params.require(:query).permit(:freq_timeframe, :freq_placeframe, :freq_organizationframe, :freq_roleframe, freq_states: [], freq_organizations: [], freq_roles: [])
	end

end
