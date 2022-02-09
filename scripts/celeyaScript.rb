require "pp"
years = %w{2018 2019 2020 2021}
myArr = [years]
national = Victim.all.where.not(:age=>nil)
state = State.where(:name=>"Guanajuato").last.victims.where.not(:age=>nil)
county = County.where(:name=>"Celaya").last.victims.where.not(:age=>nil)
places = [national, state, county] 
places.each{|place|
	placeArr = []
	years.each{|year|
		x = place.merge(Year.where(:name=>year).last.victims)
		y = x.merge(Victim.where('age <= ?',20))
		placeArr.push(y.length/x.length.to_f)
	}
	myArr.push(placeArr)
}
pp myArr