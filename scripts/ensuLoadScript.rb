require 'csv'

myFile = Quarter.where(:name=>"2020_Q1").last.survey.download
myFile = myFile.force_encoding("UTF-8")
rawData = myFile
# print rawData

surveyArr = []
rawData.each_line{|l| line = l.split(","); surveyArr.push(line)}
# print surveyArr

# myTest = CSV.read('inegi/ensu/2020_Q1.csv')
# print myTest

# if surveyArr == myTest
# 	print "WORKING!!!!"
# end

# stateName = ["Aguascalientes", "Baja California", "Baja California Sur", "Campeche", "Coahuila", "Colima", "Chiapas", "Chihuahua", "Ciudad de México", "Durango", "Guanajuato", "Guerrero", "Hidalgo", "Jalisco", "México", "Michoacán", "Morelos", "Nayarit", "Nuevo León", "Oaxaca", "Puebla", "Querétaro", "Quintana Roo", "San Luis Potosí", "Sinaloa", "Sonora", "Tabasco", "Tamaulipas", "Tlaxcala", "Veracruz", "Yucatán", "Zacatecas"]

l = surveyArr.length-1

State.all.each{|state|
	stateArr = []
	statePopulation = 0
	feel_safe = 0
	state.ensu_cities.each{|city|
		cityArr = []
		(0..l).each{|x|
			if surveyArr[x][0]
				if surveyArr[x][0] == city
					statePopulation += surveyArr[x][1].delete(' ').to_i
					cityArr.push(surveyArr[x][0],surveyArr[x][1].delete(' ').to_i,surveyArr[x+1][4].to_f)
				end
			end
		}
		stateArr.push(cityArr)
		# print stateArr
	}
	stateArr.each{|y|
		print statePopulation
		print y
		myShare = ((y[1].to_f/statePopulation.to_f))
		myPoints = myShare*y[2]
		feel_safe += myPoints
	}
	print state.name+','+feel_safe.to_s+'************'+"\n"
}



