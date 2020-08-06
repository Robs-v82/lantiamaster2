# governments = Division.find(138).organizations
# governments.each{|government|
# 	stateName = government.name[15..-1]
# 	myState = State.where(:name=>stateName).last
# 	myCode = myState.code+"000"
# 	myCounty = County.where(:full_code=>myCode).last.id
# 	government.update(:county_id=>myCounty)
# }

myCount = 0
(1..32).each{|x|
	organization = State.find(x).organizations.where(:league=>"CONAGO").last.id
	Member.find(x+86).update(:organization_id=>organization)
}