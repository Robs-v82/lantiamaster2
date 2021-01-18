require 'pp'
stateHash = {}
State.all.each{|s|
	yearVictims = Year.where(:name=>"2019").last.victims.merge(s.victims)
	print yearVictims.length
	valid = yearVictims.where.not(:age=>nil).length
	young = yearVictims.where('age < ?', 25).length
	product = young/valid.to_f
	stateHash[s.name] = product
	# print "*****"+s.name
	# print ": "
	# print product.round(3)
}
pp stateHash

print "hello world"

