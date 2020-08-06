# CREATE MONTHS

(2000..2029).each{|year|
	 %w{01 02 03 04 05 06 07 08 09 10 11 12}.each{|m|
	 	if m == "01" || m == "02" || m == "03"
	 		myQuarter = year.to_s+"_"+"Q1"
	 	elsif  m == "04" || m == "05" || m == "06"
	 		myQuarter = year.to_s+"_"+"Q2"
	 	elsif  m == "07" || m == "08" || m == "09"
	 		myQuarter = year.to_s+"_"+"Q3"
	 	elsif  m == "10" || m == "11" || m == "12"
	 		myQuarter = year.to_s+"_"+"Q4"
	 	end
	 	myQuarter = Quarter.where(:name=>myQuarter).last.id
	 	myName = year.to_s+"_"+m
	 	Month.create(:name=>myName,:quarter_id=>myQuarter)
	 }
}

# UPDATE THE FIRST DAY OF EACH MONTH
Month.all.each{|month|
	myName = month.name
	myYear = myName[0..3]
	myMonth = myName[5..6]
	first_day = myYear+"-"+myMonth+"-01"
	month.update(:first_day=>first_day)
}