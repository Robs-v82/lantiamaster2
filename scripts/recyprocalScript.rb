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