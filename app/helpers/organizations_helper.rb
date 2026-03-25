module OrganizationsHelper
	
	def recyprocal_organizations
	  organizations = Organization.all.index_by(&:id)

	  # 1. Limpiar todas las relaciones recíprocas
	  organizations.each_value do |org|
	    current_allies = Array(org.allies).map(&:to_i)
	    current_rivals = Array(org.rivals).map(&:to_i)

	    cleaned_allies = current_allies.select do |ally_id|
	      ally = organizations[ally_id]
	      ally.present? && Array(ally.allies).map(&:to_i).include?(org.id)
	    end

	    cleaned_rivals = current_rivals.select do |rival_id|
	      rival = organizations[rival_id]
	      rival.present? && Array(rival.rivals).map(&:to_i).include?(org.id)
	    end

	    org.update_columns(
	      allies: cleaned_allies.uniq,
	      rivals: cleaned_rivals.uniq
	    )
	  end

	  # 2. Volver a imponer reciprocidad con base en el estado actual
	  organizations = Organization.all.index_by(&:id)

	  organizations.each_value do |org|
	    org_id = org.id

	    Array(org.allies).map(&:to_i).each do |ally_id|
	      ally = organizations[ally_id]
	      next unless ally

	      ally_allies = Array(ally.allies).map(&:to_i)
	      unless ally_allies.include?(org_id)
	        ally.update_columns(allies: (ally_allies + [org_id]).uniq)
	      end
	    end

	    Array(org.rivals).map(&:to_i).each do |rival_id|
	      rival = organizations[rival_id]
	      next unless rival

	      rival_rivals = Array(rival.rivals).map(&:to_i)
	      unless rival_rivals.include?(org_id)
	        rival.update_columns(rivals: (rival_rivals + [org_id]).uniq)
	      end
	    end
	  end
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

	def indexCartels(cartels)
		myIndex = Organization.joins(:leads).group('organizations.id').having('count(organization_id) > 1')
		myIndex = myIndex.where(:active=>true)
		finalCartels = myIndex.merge(cartels)
		finalCartels = finalCartels.sort_by{|c| c.id}
		return finalCartels
	end

end
