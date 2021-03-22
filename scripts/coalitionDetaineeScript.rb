agencyArr = []
agencyArr.push(Organization.where(:name=>"Secretaría de la Defensa Nacional").last, Organization.where(:name=>"Secretaría de Marina").last, Organization.where(:name=>"Guardia Nacional").last, Organization.where(:name=>"Fiscalía General de la República").last)

federal = []
agencyArr.each{|agency|
	agency.detainees.each{|d|
		federal.push(d)
	}
}

coalitionHash = {}
finalHash = {}
keys = ["Cártel de Sinaloa","Cártel Jalisco Nueva Generación"]
keys.each{|key|
	counter = 0
	myMembers = []
	Organization.where(:coalition=>key).each{|cartel|
		cartel.members.each{|m|
			if federal.include? m
				myMembers.push(m)
			end
		}
		counter += cartel.members.length
	}
	coalitionHash[key] = counter
	finalHash[key] = myMembers.length
}

print coalitionHash
print finalHash

