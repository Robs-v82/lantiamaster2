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

  	def back_one_q(quarter)
 	  	key_one_q = quarter.name[5,2]
	  	if key_one_q == "Q4"
	  		key_one_q = quarter.name[0,4] + "_Q3"
	  	elsif key_one_q == "Q3"
	  		key_one_q = quarter.name[0,4] + "_Q2"
	  	elsif key_one_q == "Q2"
	  		key_one_q = quarter.name[0,4] + "_Q1"
	  	elsif key_one_q == "Q1"
	  		key_one_q = quarter.name[0,4].to_i
	  		key_one_q = key_one_q - 1
	  		key_one_q = key_one_q.to_s + "_Q4"
	  	end
	  	back_one_q = Quarter.where(:name=>key_one_q).last
	  	return back_one_q  		
  	end

  	def back_one_y(quarter)
	  	key_one_y = quarter.name[0,4].to_i
	  	key_one_y = (key_one_y-1).to_s+quarter.name[4,3]
	  	back_one_y = Quarter.where(:name=>key_one_y).last 
	  	return back_one_y
  	end

 	def quarter_score_trend(current_quarter_score, back_one_quarter_score, back_one_year_score)
 		change = (current_quarter_score - back_one_quarter_score) + (current_quarter_score - back_one_year_score)
		if change  < -0.5
			trend = "Mejora"
		elsif change < 0.5
			trend = "Estable"
		else
			trend = "Deterioro"
		end	
		return trend
 	end	

 	def previousYearQuarters(quarter)
 	 	myArr = []
        [3,2,1].each{|x|
            t = (quarter.first_day - (x*90).days).strftime('%m-%Y')
            Quarter.all.each{|q|
                if (q.first_day.strftime('%m-%Y')) == t
                   myArr.push(q)
                end
            } 
        }
        return myArr
 	end

end
