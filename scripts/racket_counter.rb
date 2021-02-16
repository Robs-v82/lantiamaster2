counter = 0
County.all.each{|c|
	if c.rackets.length > 0
		counter += 1
	end
}
print counter