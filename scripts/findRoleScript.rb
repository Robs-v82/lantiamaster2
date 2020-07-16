

require 'pp'

# FIND CIVIL ROLES

civil_roles = Victim.pluck(:legacy_role_civil)

keyArr = civil_roles.uniq

freqArr = []

keyArr.each {|x|
	myHash = {}
	y = civil_roles.count(x)
	myHash = {"label"=>x,"freq"=>y}
	freqArr.push(myHash)
}

freqArr = freqArr.sort_by {|hsh| hsh["freq"]}

pp freqArr

# FIND OFFICIAL ROLES

civil_roles = Victim.pluck(:legacy_role_officer)

keyArr = civil_roles.uniq

freqArr = []

keyArr.each {|x|
	myHash = {}
	y = civil_roles.count(x)
	myHash = {"label"=>x,"freq"=>y}
	freqArr.push(myHash)
}

freqArr = freqArr.sort_by {|hsh| hsh["freq"]}

pp freqArr