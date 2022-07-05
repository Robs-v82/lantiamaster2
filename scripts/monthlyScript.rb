myMonth = Month.where(:name=>"2022_04").last
p_killings = myMonth.killings
p_victims = myMonth.victims

femaleArr = []

State.all.each{|state|
	localVictims = state.victims.merge(p_victims)
}