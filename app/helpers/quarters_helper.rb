module QuartersHelper

	def quarter_strings(quarter)
	  	quarterString = quarter.name[5..6]
	  	if quarterString == "Q1"
	  		quarterText = "Primer trimestre"
	  		quarterShort = "T1"
	  	elsif quarterString == "Q2"
	  		quarterText = "Segundo trimestre"
	  		quarterShort = "T2"
	  	elsif quarterString == "Q3"
	  		quarterText = "Tercer trimestre"
	  		quarterShort = "T3"
	  	elsif quarterString == "Q4"
	  		quarterText = "Cuarto trimestre"
	  		quarterShort = "T4"
	  	end
	  	myDate = quarter.first_day
	  	myHash = {:quarterText=>quarterText, :quarterShort=>quarterShort, :quarterDate=>myDate}
	  	return myHash
  	end
  	
end
