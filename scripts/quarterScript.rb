
# ADD YEARS
(2000..2029).each{|year|
	year = year.to_s
	myDay = year+"-01-01"
	Year.create(:name=>year, :first_day=>myDay)
}

myArr = ["Q1","Q2","Q3","Q4"]
myArr.each{|q|
	Year.all.each{|y|
		myName = y.name+"_"+q
	 	Quarter.create(:name=>myName, :year_id=>y.id)
	}	
} 

# UPDATE QUARTERS

Quarter.all.each{|q|
	myYear = q.name[0..3]
	qNumber = q.name[5..6]
	print myYear
	print qNumber
	if qNumber == "Q1"
		myMonth = "01"
	elsif qNumber == "Q2"
		myMonth = "04"
	elsif qNumber == "Q3"
		myMonth = "07"
	elsif qNumber == "Q4"
		myMonth = "10"
	end
	thisYear = Year.where(:name=>myYear).last.id
	myDay = myYear+"-"+myMonth+"-01"
	q.update(:first_day=>myDay, :year_id=>thisYear)
}