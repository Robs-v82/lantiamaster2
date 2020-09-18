module OrganizationsHelper

	def recyprocal_organizations
		Organization.all.each{|cartel|
			x = cartel.id

			# MAKE SURE ALL RIVALRIES ARE RECYPROCAL
			cartel.rivals.each{|y|
				myRival = Organization.find(y) 
				unless myRival.rivals.include? x
					rivalArr = Organization.find(y).rivals
					rivalArr.push(x)
					rivalArr = rivalArr.uniq
					myRival.update(:rivals=>rivalArr)
				end
			}

			# MAKE SURE ALL ALLIANCES ARE RECYPROCAL
			cartel.allies.each{|y|
				myAlly = Organization.find(y) 
				unless myAlly.allies.include? x
					alliesArr = Organization.find(y).allies
					alliesArr.push(x)
					alliesArr = alliesArr.uniq
					myAlly.update(:allies=>alliesArr)
				end
			}

		}		
	end

	def update_league
		cartels = Sector.where(:scian2=>98).last.organizations.uniq
		cartels.each{|cartel|
			unless cartel.league.nil?
				myName = cartel.league
				myLeague = League.where(:name=>myName).last.id
				unless  myLeague.nil?
					cartel.update(:mainleague_id=>myLeague) 	
				end
			end
			unless cartel.subleague.nil?
				unless cartel.subleague.empty?
					myName = cartel.subleague
					mySubLeague = League.where(:name=>myName).last.id
					unless  mySubLeague.nil?
						cartel.update(:subleague_id=>mySubLeague) 	
					end 
				end
			end
		}
	end

	def get_detainees_cartels
		cartels = Sector.where(:scian2=>"98").last.organizations.uniq
		cartelArr = []
		cartels.each{|cartel|
			unless cartel.members.where.not(:detention_id=>nil).empty?
				myString = cartel.name
				cartelArr.push(myString)
			end
		}
		return cartelArr
	end

end
