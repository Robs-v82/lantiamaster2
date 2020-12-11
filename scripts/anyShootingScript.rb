Killing.all.each{|killing|
	if killing.shooting
		killing.update(:any_shooting=>true)
	elsif killing.shooting_between_criminals_and_authorities
		killing.update(:any_shooting=>true)
	elsif killing.shooting_among_criminals
		killing.update(:any_shooting=>true)
	end
}