myArr = []
myData = Cookie.where(:category=>"irco_counties").last.data
myData.each{|x| thisArr = []; thisArr.push(x["code"]); thisArr.push(x[:name]); thisArr.push(x["2020_Q4"]); thisArr.push(x["2021_Q1"]); thisArr.push(x["2021_Q2"]); thisArr.push(x["2021_Q3"]); thisArr.push(x["2021_Q4"]); thisArr.push(x["2022_Q1"]); thisArr.push(x["2022_Q2"]); thisArr.push(x[:score]); myArr.push(thisArr)}