years = ["2022","2023","2024"]
quarters = ["_Q1","_Q2","_Q3","_Q4"]
gobArr = []
years.each{|y| quarters.each{|q| thisArr =[y+q]; myQuarter = Quarter.where(:name=>y+q).last.id; myCookie = Cookie.where(:category=>"icon", :quarter_id=>myQuarter).last.data; myCookie.each{|c| thisArr.push(c["gob"])}; gobArr.push(thisArr)}}









