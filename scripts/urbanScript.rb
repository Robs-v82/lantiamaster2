require "pp"
myArr = []
["2018","2019","2020","2021"].each{|year|
	yearVictims = Year.where(:name=>year).last.victims
	yearArr = [year, yearVictims.length]
	counter = 0
	City.all.each{|city|
		counter += city.victims.merge(yearVictims).length
	}
	yearArr.push(counter)
	myArr.push(yearArr)
}
pp myArr
