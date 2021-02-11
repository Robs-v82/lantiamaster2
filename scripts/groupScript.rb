cartels = Sector.where(:scian2=>"98").last.organizations.uniq
	groupKeys = [
			{"name"=>"Cártel de Sinaloa","color"=>'#80cbc4',"dark_color"=>'#00897b',"material_color"=>'teal'},
			{"name"=>"Cártel Jalisco Nueva Generación","color"=>'#ffcc80',"dark_color"=>'#ffc107',"material_color"=>'orange'},
			{"name"=>"Cártel del Noreste","color"=>'#4c4699'},
			{"name"=>"La Unión Tepito","color"=>'#e0e0e0'}
	]
cartels.each{|cartel|
	cartelIn = false
	groupKeys.each{|coalition|
		leader = Organization.where(:name=>coalition["name"]).last
		if leader
			if cartel.name == leader.name or leader.subordinates.include? cartel or leader.allies.include? cartel.id
				cartel.update(:group=>coalition["name"])
			end
		end
	}
}