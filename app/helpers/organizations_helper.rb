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

	def get_cartels
		cartels = Sector.where(:scian2=>"98").last.organizations.uniq
		cartels = cartels.sort_by{|c| c.name}
		return cartels
	end

	def coalitionKeys
		coalitionKeys = [
  			{"name"=>"Cártel de Sinaloa","color"=>'#80cbc4',"dark_color"=>'#00897b',"material_color"=>'teal'},
  			{"name"=>"Cártel Jalisco Nueva Generación","color"=>'#ffcc80',"dark_color"=>'#ffc107',"material_color"=>'orange'},
  			{"name"=>"Sin coalición","color"=>'#454157',"dark_color"=>'#454157',"material_color"=>'paletton-grey'}
  		]
		return coalitionKeys
	end

	def groupKeys
		groupKeys = [
  			{"name"=>"Cártel de Sinaloa","color"=>'#53A89F',"dark_color"=>'#00897b',"material_color"=>'teal'},
  			{"name"=>"Cártel Jalisco Nueva Generación","color"=>'#FFD17D',"dark_color"=>'#ffc107',"material_color"=>'orange'},
  			{"name"=>"Cártel del Noreste","color"=>'#FFB47D'},
  			{"name"=>"La Unión Tepito","color"=>'#607DB2'}
		]
		return groupKeys
	end

	def law_enforcement
		myArr = []
		myArr.push(Organization.where(:name=>"Secretaría de la Defensa Nacional").last, Organization.where(:name=>"Secretaría de Marina").last, Organization.where(:name=>"Guardia Nacional").last, Organization.where(:name=>"Fiscalía General de la República").last)
	end

end
