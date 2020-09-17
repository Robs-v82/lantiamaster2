class MembersController < ApplicationController
	
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
					Event.create(:event_date=>myDate, :town_id=>targetTown.id)
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

	private

	def detention_params
		params.require(:query).permit(:file)
	end

end
