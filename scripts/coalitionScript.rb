cartels = Sector.where(:scian2=>"98").last.organizations.uniq
coalitionKeys = [
	{"name"=>"Cártel de Sinaloa","color"=>'#80cbc4',"dark_color"=>'#00897b',"material_color"=>'teal'},
	{"name"=>"Cártel Jalisco Nueva Generación","color"=>'#ffcc80',"dark_color"=>'#ffc107',"material_color"=>'orange'},
	{"name"=>"Sin coalición","color"=>'#e0e0e0',"dark_color"=>'#7f7b90',"material_color"=>'paletton-grey'}
]
cartels.each{|cartel|
	cartelIn = false
	coalitionKeys.each{|coalition|
		leader = Organization.where(:name=>coalition["name"]).last
		if leader
			if cartel.name == leader.name or leader.subordinates.include? cartel or leader.allies.include? cartel.id
				cartel.update(:coalition=>coalition["name"],:color=>coalition["color"])
				cartelIn = true	
			end
		end
	}
	unless cartelIn
		cartel.update(:coalition=>coalitionKeys[2]["name"],:color=>coalitionKeys[2]["color"])
		cartelIn = true				
	end
}