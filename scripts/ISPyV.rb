require 'csv'

myFile = Quarter.where(:name=>"2020_Q1").last.survey.download
myFile = myFile.force_encoding("UTF-8")
rawData = myFile

surveyArr = []
rawData.each_line{|l| line = l.split(","); surveyArr.push(line)}
surveyArr.each{|x|x.each{|y|y.strip!}}


l = surveyArr.length-1

State.all.each{|state|
	stateArr = []
	statePopulation = 0
	feel_safe = 0
	state.ensu_cities.each{|city|
		(0..l).each{|x|
			if surveyArr[x][0]
				if surveyArr[x][0] == city and surveyArr[x][1] !=""
					cityArr = []
					statePopulation += surveyArr[x][1].delete(' ').to_i
					cityArr.push(surveyArr[x][0],surveyArr[x][1].delete(' ').to_i,surveyArr[x+1][4].to_f)
					stateArr.push(cityArr)
				end
			end
		}
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