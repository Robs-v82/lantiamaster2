rawData = "14,Pablo,Lemus,Navarro,gobernador14.jpg
30,Rocío,Nahle,García,gobernador30.jpg
31,Joaquín,Díaz,Mena,gobernador31.jpg
11,Libia Dennise,García,Muñoz Ledo,gobernador11.jpg
17,Margarita,González,Saravia,gobernador17.jpg
07,Eduardo,Ramírez,Aguilar,gobernador07.jpg"

governorArr = []
rawData.each_line{|l| line = l.split(","); governorArr.push(line)}
governorArr.each{|x|x.each{|y|y.strip!}}

governorArr.each{|x|
	state = State.where(:code=>x[0]).last
	g = Organization.where(:name=>"Gubernatura de "+state.name).last.members.last
	g.update(:firstname => x[1],
		:lastname1 =>  x[2],
		:lastname2 => x[3])
	g.avatar.purge
	downloaded_image = URI.open(Rails.root / 'app' / 'assets' / 'images' / x[4])
	governor.avatar.attach(io: downloaded_image, filename: x[4])
}

print "Ready :-)"

# if Role.where(:name=>"Gobernador").empty?
# 	Role.create(:name=>"Gobernador")	
# end
# governorKey = Role.where(:name=>"Gobernador").last.id



# State.all.each{|state|
# 	myName = "Gubernatura de "+state.name
# 	myCode = state.code+"000"
# 	myCounty = County.where(:full_code=>myCode).last.id
# 	if Organization.where(:name => myName).empty?
# 		Organization.create(:name => myName, :league => "CONAGO", :county_id => myCounty)
# 	end
# 	government = Division.where(:scian3=>931).last
# 	Organization.last.divisions << government
# 	}

# UPATE GOVERNORS' INFORMATION
# State.all.each{|state|
# 	myName = "Gubernatura de "+state.name
# 	organization_id = Organization.where(:name => myName).last.id
# 	stateMembers = Organization.where(:name => myName).last.members
# 	governor = stateMembers.where(:role_id=>governorKey).last
# 	governorArr.each{|x|
# 		filename = "gobernador"+x[1]+".jpg"
# 		downloaded_image = URI.open(Rails.root / 'app' / 'assets' / 'images' / x[4])
# 		print filename
# 		if x[0] == state.code
# 			if governor == nil	
# 				Member.create(
# 					:firstname => x[1],
# 					:lastname1 =>  x[2],
# 					:lastname2 => x[3],
# 					:organization_id => organization_id,
# 					:role_id => governorKey
# 				)
# 				member.last.avatar.attach(io: downloaded_image, filename: filename)
# 			else
# 				governor.update(
# 					:firstname => x[1],
# 					:lastname1 =>  x[2],
# 					:lastname2 => x[3],
# 				)
# 				governor.avatar.purge
# 				governor.avatar.attach(io: downloaded_image, filename: filename)
# 			end
# 		end
# 	}		
	
# }

# testUpdate