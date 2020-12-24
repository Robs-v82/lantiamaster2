state = State.second
myFloat = 0.0
conflictCounty = false
state.counties.where.not(:name=>"Sin definir").each{|county|
	unless county.population.nil?
		conflictScore = 0.0
		county.rackets.each{|racket|
			racket.rivals.each{|x|
				rival = Organization.find(x)
				if county.rackets.include? rival
					conflictScore += 0.25
				end
			}
		}
		if conflictScore > 1.0
			conflictScore = 1.0
		end
		countyPop = county.population
		statePop = state.population
		share = countyPop/statePop.to_f
		addition = share*conflictScore
		myFloat += addition
	end
}
print "******RESULT: "
print myFloat
	
