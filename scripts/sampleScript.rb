require 'pp'

j = State.where(:name=>"Jalisco").last
jk = j.killings
q = Quarter.where(:name=>"2021_Q2").last.killings
jkq = jk.merge(q)

print "LENGTH: "
print jkq.length

myArr = []
jkq.each {|k|
	killingArr = []
	killingArr.push(k.event.event_date.to_formatted_s(:short))
	killingArr.push(k.event.town.county.full_code)
	killingArr.push(k.event.town.county.name)
	killingArr.push(k.event.town.full_code)
	killingArr.push(k.event.town.name)
	myArr.push(killingArr)
}

pp myArr
