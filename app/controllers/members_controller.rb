class MembersController < ApplicationController
	
	after_action :remove_email_message, only: [:detainees]

	skip_before_action :verify_authenticity_token

	before_action :require_pro, only: [:detainees]
	before_action :require_detention_access, only: [:detainees]

	require 'pp'

	def detentions
		Detention.all.each{|i|
			i.detainees.destroy_all
			i.destroy
		}
		myFile = detention_params[:file]
		table = CSV.parse(File.read(myFile))
		table.each{|x|
			x = x.collect{ |e| e ? e.strip : e}
			targetOrganization = Organization.where(:name=>x[10]).last
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
						Detention.create(:event_id=>targetEvent.id,:legacy_id=>x[0].to_i)
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
						targetDetention = Detention.where(:legacy_id=>x[0].to_i).last
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
						end
						targetMember.update(:detention_id=>targetDetention.id)
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
		redirect_to "/members/detainees_freq_api"	
	end

	def new_query
		helpers.clear_session
		dataCookie = Cookie.where(:category=>"detainees_state_monthly_API").last.data[0]
		organizationOptions = dataCookie[:organizations]
		roleOptions = []
		myRoles = Role.where(:criminal=>true)
		myRoles.each{|role|
			roleOptions.push(role.id.to_s)
		} 
		myArr = State.pluck(:id)
		Cookie.create(:data=>myArr, :category=>"detainee_query_cookie")
		session[:checkedStates] = Cookie.last.id
		session[:checkedOrganizations] = false
		session[:checkedRoles] = false
		Cookie.create(:category=>"detainee_freq_params_"+session[:user_id].to_s, :data=>["monthly","stateWise","noOrganizationSplit", "noRoleSplit", organizationOptions, false, false, roleOptions])
		redirect_to "/members/detainees"
	end

	def query
		paramsStates = Cookie.find(session[:checkedStates]).data.length
		paramsCookie = Cookie.where(:category=>"detainee_freq_params_"+session[:user_id].to_s).last.data
		if detainee_freq_params[:freq_timeframe]
			paramsCookie[0] = detainee_freq_params[:freq_timeframe]
		end
		if detainee_freq_params[:freq_placeframe]
			paramsCookie[1] = detainee_freq_params[:freq_placeframe]
		end
		if detainee_freq_params[:freq_organizationframe]
			paramsCookie[2] = detainee_freq_params[:freq_organizationframe]
		end
		if detainee_freq_params[:freq_roleframe]
			paramsCookie[3] = detainee_freq_params[:freq_roleframe]
		end
		if detainee_freq_params[:freq_organizations]
			paramsCookie[4] = detainee_freq_params[:freq_organizations]
		end
		if detainee_freq_params[:freq_states]
			if paramsStates == 32
				paramsCookie[5] = false
			else
				paramsCookie[5] = true				
			end
			myArr = detainee_freq_params[:freq_states].map(&:to_i)
			Cookie.create(:data=>myArr)
			session[:checkedStates] = Cookie.last.id
		end
		if detainee_freq_params[:freq_organizations]
			paramsCookie[6] = detainee_freq_params[:freq_organizations]
			session[:checkedOrganizations] = paramsCookie[6]
		end
		if detainee_freq_params[:freq_roles]
			paramsCookie[7] = detainee_freq_params[:freq_roles]
			session[:checkedRoles] = paramsCookie[7]
		end
		Cookie.where(:category=>"detainee_freq_params_"+session[:user_id].to_s).last.update(:data=>paramsCookie)
		logger.info("XXxx"*300)
		logger.info(session.inspect)
		redirect_to "/members/detainees"
	end

	def api_or_table
		paramsCookie = Cookie.where(:category=>"detainee_freq_params_"+session[:user_id].to_s).last.data
		paramsCookie[5] = session[:checkedStates] 
		if Cookie.find(session[:checkedStates]).data.length < 32 || paramsCookie[2] == "organizationSplit" || paramsCookie[3] == "roleSplit"
			table = detainee_freq_table(
				paramsCookie[0],
				paramsCookie[1],
				paramsCookie[2],
				paramsCookie[3],
				paramsCookie[4],
				paramsCookie[5],
				paramsCookie[6],
				paramsCookie[7]
			)
		else		 
			if paramsCookie[0] == "monthly" && paramsCookie[1] == "stateWise"
				table = Cookie.where(:category=>"detainees_state_monthly_API").last.data[0][:table]
			elsif paramsCookie[0] == "quarterly" && paramsCookie[1] == "stateWise"
				table = Cookie.where(:category=>"detainees_state_quarterly_API").last.data[0][:table]
			elsif paramsCookie[0] == "monthly" && paramsCookie[1] == "nationWise"
				table = Cookie.where(:category=>"detainees_national_monthly_API").last.data[0][:table]
			elsif paramsCookie[0] == "quarterly" && paramsCookie[1] == "nationWise"
				table = Cookie.where(:category=>"detainees_national_quarterly_API").last.data[0][:table]
			else
				table = detainee_freq_table(
					paramsCookie[0],
					paramsCookie[1],
					paramsCookie[2],
					paramsCookie[3],
					paramsCookie[4],
					paramsCookie[5],
					paramsCookie[6],
					paramsCookie[7]
				)
			end
		end
		return table
	end

	def detainees
		@paramsCookie = Cookie.where(:category=>"detainee_freq_params_"+session[:user_id].to_s).last.data 
		dataCookie = Cookie.where(:category=>"detainees_state_monthly_API").last.data[0]
		@user = User.find(session[:user_id])
		@my_freq_table = api_or_table
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
  		if @paramsCookie[0] == "quarterly"
  			@timeFrames[0][:checked] = true
  			@quarterly = true
  		else
  			@timeFrames[1][:checked] = true
  		end

  		if @paramsCookie[2] == "noOrganizationSplit"
  			@organizationFrames[0][:checked] = true
  		else
  			@organizationFrames[1][:checked] = true
  		end

  		if @paramsCookie[3] == "noRoleSplit"
  			@roleFrames[0][:checked] = true
  		else
  			@roleFrames[1][:checked] = true
  		end

  		if @paramsCookie[1] == "nationWise"
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

		@organizations = dataCookie[:organizations]
		if session[:checkedOrganizations]
			@checkedOrganizations = @paramsCookie[6]
		else
			@checkedOrganizations = @organizations
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

		@maps = false
		if @stateWise && @checkedStates.length == State.all.length
			@maps = true
		end
		@detention_cartels = helpers.detention_cartels
		@topDetentions = dataCookie[:topDetentions]
		@topDetentionRoles = helpers.top_detention_roles
		@fileHash = {:data=>@my_freq_table,:formats=>['csv']}
		logger.info("XXxx"*300)
		logger.info(session.inspect)
	end

	def detainees_freq_api
		helpers.clear_session
		# paramsCookie = Cookie.where(:category=>"detainee_freq_params_"+session[:user_id].to_s).last.data
		organizationOptions = helpers.get_detainees_cartels
		roleOptions = []
		myRoles = Role.where(:criminal=>true)
		myRoles.each{|role|
			roleOptions.push(role.id.to_s)
		} 
		myArr = State.pluck(:id)
		dataHash = {}
		dataHash[:organizations] = helpers.get_detainees_cartels
		dataHash[:topDetentions] = get_top_detentions
		Cookie.create(:data=>myArr)
		session[:checkedStates] = Cookie.last.id
		session[:checkedOrganizations] = false
		session[:checkedRoles] = false
		paramsCookie = ["monthly","stateWise","noOrganizationSplit", "noRoleSplit", organizationOptions, false, false, roleOptions]
		dataHash[:table] = detainee_freq_table(
			paramsCookie[0],
			paramsCookie[1],
			paramsCookie[2],
			paramsCookie[3],
			paramsCookie[4],
			session[:checkedStates],
			paramsCookie[6],
			paramsCookie[7]
		)
		Cookie.create(:data=>[dataHash], :category=>"detainees_state_monthly_API")

		paramsCookie = ["quarterly","stateWise","noOrganizationSplit", "noRoleSplit", organizationOptions, false, false, roleOptions]
		dataHash[:table] = detainee_freq_table(
			paramsCookie[0],
			paramsCookie[1],
			paramsCookie[2],
			paramsCookie[3],
			paramsCookie[4],
			session[:checkedStates],
			paramsCookie[6],
			paramsCookie[7]
		)
		Cookie.create(:data=>[dataHash], :category=>"detainees_state_quarterly_API")

		paramsCookie = ["monthly","nationWise","noOrganizationSplit", "noRoleSplit", organizationOptions, false, false, roleOptions]
		dataHash[:table] = detainee_freq_table(
			paramsCookie[0],
			paramsCookie[1],
			paramsCookie[2],
			paramsCookie[3],
			paramsCookie[4],
			session[:checkedStates],
			paramsCookie[6],
			paramsCookie[7]
		)
		Cookie.create(:data=>[dataHash], :category=>"detainees_national_monthly_API")

		paramsCookie = ["quarterly","nationWise","noOrganizationSplit", "noRoleSplit", organizationOptions, false, false, roleOptions]
		dataHash[:table] = detainee_freq_table(
			paramsCookie[0],
			paramsCookie[1],
			paramsCookie[2],
			paramsCookie[3],
			paramsCookie[4],
			session[:checkedStates],
			paramsCookie[6],
			paramsCookie[7]
		)
		Cookie.create(:data=>[dataHash], :category=>"detainees_national_quarterly_API")

		redirect_to "/datasets/load"
	end

	def detainee_freq_table(period, scope, organization, role, organizationOptions, states, organizations, roleOptions)
		myTable = []
		headerHash = {}
		totalHash = {}
		totalHash[:name] = "Total"
		groupKeys = helpers.groupKeys		

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

			# MAP DATA
			if organization == "noOrganizationSplit"
				myTable.push(headerHash)
				myScope.push("Nacional")
				myScope.each{|place|
					if place == "Nacional"
						placeName = "Nacional"
						placeCode = "00"
						localDetainees = Member.where.not(:detention_id=>nil)
						localCounties = County.where.not(:name=>"Sin definir")
					else
						placeName = place.name
						placeCode = place.code
						localDetainees = place.detainees
						localCounties = place.counties.where.not(:name=>"Sin definir")
					end
					placeHash = {}
					rolesArr = []
					myRoles.each{|r|
						roleHash = {}
						roleHash[:role] = r.name
						number_of_detainees = r.members.merge(localDetainees).length
						if number_of_detainees
							roleHash[:freq] = number_of_detainees
							rolesArr.push(roleHash)
						end
					}
					rolesArr = rolesArr.sort_by{|r| -r[:freq]}
					newRolesArr = []
					residual = 0
					colors = ['#71a110','#addf49','#d8f69b']
					colorCounter = 0
					rolesArr.each{|r|
						if newRolesArr.length < 3 && r[:role] != "Sin definir" && r[:freq] > 0
							r[:color] = colors[colorCounter]
							newRolesArr.push(r)
							colorCounter += 1
						else
							residual += r[:freq]
						end
					}
					if residual > 0
						residualHash = {:role=>"Otro/Sin definir"}
						residualHash[:freq] = residual
						residualHash[:color] = '#e0e0e0'
						newRolesArr.push(residualHash)
					end
					placeHash[:roles] = newRolesArr
					placeHash[:name] = placeName
					placeHash[:code] = placeCode
					freq = []
					counter = 0
					place_total = 0
					myPeriod.each {|timeUnit|
						number_of_detainees = localDetainees.merge(timeUnit.detainees).length
						freq.push(number_of_detainees)
						unless place == "Nacional"
							totalFreq[counter] += number_of_detainees
						end
						counter += 1
						place_total += number_of_detainees
					}
					placeHash[:freq] = freq
					placeHash[:place_total] = place_total 
					unless place_total == 0
						placeHash[:agencies] = []
						myAgencies = helpers.law_enforcement
						unless place == "Nacional"
							myAgencies.push(place.counties.where(:name=>"Sin definir").last.organizations.where(:league=>"Seguridad Pública").last)
						end
						myAgencies.each{|agency|
							agencyHash = {}
							if agency.acronym
								agencyHash[:name] = agency.acronym
							else
								agencyHash[:name] = "Policía Estatal"		
							end
							agencyShare = (agency.detainees.merge(localDetainees).length/place_total.to_f).round(2)
							agencyHash[:share] = (agencyShare*100).round(0) 
							placeHash[:agencies].push(agencyHash)								
						}
						if place == "Nacional"
							statePolice = {:name=>"Policía Estatal", :freq=>0}
							State.all.each{|state|
								statePolice[:freq] += state.counties.where(:name=>"Sin definir").last.organizations.where(:league=>"Seguridad Pública").last.detainees.length
							}
							statePoliceShare = (statePolice[:freq]/place_total.to_f).round(2)
							statePolice[:share] = (statePoliceShare*100).round(0)
							placeHash[:agencies].push(statePolice)
						end
						localPolice = {:name=>"Policía Municipal", :freq=>0}
						localCounties.each{|county|
							localPolice[:freq] += county.organizations.where(:league=>"Seguridad Pública").last.detainees.length
						}
						localPoliceShare = (localPolice[:freq]/place_total.to_f).round(2)
						localPolice[:share] = (localPoliceShare*100).round(0)
						placeHash[:agencies].push(localPolice)
						placeHash[:coalitions] = []
						helpers.groupKeys.each{|coalition|
							coalitionCounter = 0
							organizationOptions.each{|organization|
								myOrganization = Organization.where(:name=>organization).last
								if myOrganization.group == coalition["name"]
									orgNumber = localDetainees.where(:organization_id=>myOrganization.id).length
									coalitionCounter += orgNumber
								end
							}
							coalitionHash = {:name=>coalition["name"], :freq=>coalitionCounter, :color=>coalition["color"]}
							placeHash[:coalitions].push(coalitionHash)
						}
					end
					myTable.push(placeHash)
				}
				# MAP DATA END

			else
				headerHash[:organization] = "ORGANIZACIÓN"
				totalHash[:organization_placer] = "--"
				myTable.push(headerHash)
				myScope.each{|place|
					organizationOptions.each{|organization|
						placeHash = {}
						placeHash[:name] = place.name
						if scope = "stateWise"
							placeHash[:code] = place.code
						end
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
	end

	def get_top_detentions
		detentionArr = []
		topDetentionRoles = helpers.top_detention_roles
		topDetentionRoles.each{|role|
			Role.where(:name=>role).last.members.each{|myMember|
				detentionArr.push(myMember.detention)
			}
		}
		Detention.all.each{|detention|
			if detention.detainees.length > 9
				detentionArr.push(detention)
			end
		}
		detentionArr.uniq!
		detentionArr.compact!
		detentionArr = detentionArr.sort_by{|d| -d.event.event_date.to_i}
		return detentionArr
	end

	def send_file
		paramsCookie = Cookie.where(:category=>"detainee_freq_params_"+session[:user_id].to_s).last.data
		recipient = User.find(session[:user_id])
		current_date = Date.today.strftime
		records = api_or_table

		downloadCounter = recipient.downloads
		downloadCounter += 1
		recipient.update(:downloads=>downloadCounter)

	 	file_name = "arrestos_"+downloadCounter.to_s+"_"+current_date+".csv"
	 	caption = "arrestos"
		file_root = Rails.root.join("private",file_name)
		myLength = helpers.root_path[:myLength]

		myFile = helpers.send_freq_file(recipient, file_root, file_name, records, myLength, caption, params[:timeframe], paramsCookie[1], params[:extension])

		respond_to do |format|
			format.html
			format.csv { send_data myFile, filename: file_name}
		end
		# helpers.send_freq_file(recipient, file_root, file_name, records, myLength, caption, params[:timeframe], paramsCookie[1], params[:extension])

		# SHIFT TO EMAIL DELIVERY
		# QueryMailer.freq_email(recipient, file_root, file_name, records, myLength, caption, params[:timeframe], paramsCookie[1], params[:extension]).deliver_now
		# session[:email_success] = true
		# redirect_to "/members/detainees"
	end

	private

	def detention_params
		params.require(:query).permit(:file)
	end

	def detainee_freq_params
		params.require(:query).permit(:freq_timeframe, :freq_placeframe, :freq_organizationframe, :freq_roleframe, freq_states: [], freq_organizations: [], freq_roles: [])
	end
end