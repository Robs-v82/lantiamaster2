class MembersController < ApplicationController
	
	require 'pp'

	def detentions
		myFile = detention_params[:file]
		table = CSV.parse(File.read(myFile))

		table.each{|x|
			x = x.collect{ |e| e ? e.strip : e}
			unless Organization.where(:name=>x[0]).empty?
				targetOrganization = Organization.where(:name=>x[0]).last
				
				if Detention.where(:legacy_id=>x[1]).empty?
					
					# CREATE EVENT AND DETENTION IF THEY DO NOT EXIST
					myCode = helpers.zero_padded_full_code(x[6])
					targetCounty = County.where(:full_code=>myCode).last
					countyPolice = targetCounty.organizations.where(:league=>"Seguridad Pública").last.name
					targetState = targetCounty.state
					statePolice = targetState.counties.where(:name=>"Sin definir").last.organizations.where(:league=>"Seguridad Pública").last.name
					stateAttorney = targetState.counties.where(:name=>"Sin definir").last.organizations.where(:league=>"Procuración de Justicia").last.name
					targetTown = targetCounty.towns.where(:name=>"Sin definir").last
					myDate = "20"+x[4]+"-"+x[3]+"-"+x[2]
					myDate = myDate.to_datetime
					monthName = myDate.strftime("%Y")+"_"+myDate.strftime("%m")
					targetMonth = Month.where(:name=>monthName).last
					Event.create(:event_date=>myDate, :town_id=>targetTown.id, :month_id=>targetMonth.id)
					targetEvent = Event.last
					
					limit = x.length-1
					(25..limit).each{|y|
						if Source.where(:url=>x[y]).empty?
							Source.create(:url=>x[y])
							mySource = Source.last
						else
							mySource = Source.where(:url=>x[y]).last
						end
						unless targetEvent.sources.include? (mySource)
							targetEvent.sources << mySource
						end
					}
					Detention.create(:event_id=>targetEvent.id,:legacy_id=>x[1])
					targetDetention = Detention.last

					# ADD AUTHORITIES
					policeArr = [
						{:name=>"Secretaría de la Defensa Nacional" , :slot=>17},
						# {:name=>"Secretaría de Marina", :slot=>},
						{:name=>"Guardia Nacional", :slot=>18},
						{:name=>"Policía Federal", :slot=>19},
						{:name=>"Fiscalía General de la República", :slot=>20},
						{:name=>statePolice, :slot=>21},
						{:name=>stateAttorney, :slot=>22},
						{:name=>countyPolice, :slot=>23}
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
					targetDetention = Detention.where(:legacy_id=>x[1]).last
				end

				# DEFINE ROLE
				unless Role.where(:name=>x[16]).empty?
					targetRole = Role.where(:name=>x[16]).last
				else
					targetRole = nil
				end

				# ADD DATEAINEES
				unless x[9].nil?
					if x[9] == 1
						unless x[10].nil? && x[13].nil?
							if targetOrganization.members.where(:firstname=>x[10],:lastname1=>x[11],:lastname2=>x[12]).empty?
								myAlias = nil
								unless x[13].nil?
									myAlias = x[13].split(";")
								end
								Member.create(:organization_id=>targetOrganization.id,:firstname=>x[10],:lastname1=>x[11],:lastname2=>x[12], :alias=>myAlias)
								targetMember = Member.last
							else
								targetMember = targetOrganization.members.where(:firstname=>x[10],:lastname1=>x[11],:lastname2=>x[12]).last
							end
							targetMember.update(:detention_id=>targetDetention.id)
						else
							Member.create(:organization_id=>targetOrganization.id)
							targetMember = Member.last						
						end
						targetMember.update(:role_id=>targetRole.id)
					else
						count = x[9].to_i
						(1..count).each{
							Member.create(:organization_id=>targetOrganization.id,:detention_id=>targetDetention.id)
							if targetRole
								Member.last.update(:role_id=>targetRole.id)
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
		organizationOptions = helpers.get_detainees_cartels
		session[:detainee_freq_params] = ["quarterly","nationWise","organizationSplit", "noRoleSplit", organizationOptions]
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
		redirect_to "/members/detainees"
	end

	def detainees
		@my_freq_table = detainee_freq_table(session[:detainee_freq_params][0], session[:detainee_freq_params][1], session[:detainee_freq_params][2], session[:detainee_freq_params][3], session[:detainee_freq_params][4])
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
  			@placeFrames[0][:checked] = true
  		else
  			@placeFrames[1][:checked] = true
  		end

		@sortCounter = 0
	end

	def detainee_freq_table(period, scope, organization, role, organizationOptions)
		print "********WORKING ON TABLE!"

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

		myStates = State.all.sort
		if scope == "nationWise"
			myScope = nil
		elsif scope == "stateWise"
			headerHash[:scope] = "ESTADO"
			myScope = myStates
		end

		totalFreq = []
		(1..myPeriod.length).each {
			totalFreq.push(0)
		}

		headerHash[:period] = myPeriod

		roleOptions = Role.where(:criminal=>true)

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
					roleOptions.each{|r|
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
						roleOptions.each{|r|
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
		params.require(:query).permit(:freq_timeframe, :freq_placeframe, :freq_organizationframe, :freq_roleframe)
	end

end
