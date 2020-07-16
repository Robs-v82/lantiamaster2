# State.all.each{|x|
# 	# CREATE LAW ENFORCEMENT AGENCIES
# 	myCode = x.code+"000"
# 	myCounty = County.where(:full_code=>myCode).last.id
# 	stateName = x.name
# 	policeName = "Policía Estatal de "+stateName
# 	if Organization.where(:name=>policeName).empty?
# 		Organization.create(:name=>policeName,:county_id=>myCounty)
# 	end

# 	# CREATE DEPARTMENTS OF JUSTICE
# 	justiceName = "Fiscalía General de Justicia de "+stateName
# 	if Organization.where(:name=>justiceName).empty?
# 		Organization.create(:name=>justiceName,:county_id=>myCounty)
# 	end
# }

# County.where.not(:code=>"000").each{|x|
# 	# CREATE LAW ENFORCEMENT AGENCIES
# 	myCode = x.code+"000"
# 	myCounty = x.id
# 	countyName = x.name
# 	policeName = "Policía Municipal de "+countyName
# 	if Organization.where(:name=>policeName).empty?
# 		Organization.create(:name=>policeName,:county_id=>myCounty)
# 	end
# }

# # GET COUNTIES THAT SHARE THE SAME NAME
# county_names = County.pluck(:name)
# keyArr = county_names.uniq
# freqArr = []
# keyArr.each {|x|
# 	myHash = {}
# 	y = county_names.count(x)
# 	myHash = {"label"=>x,"freq"=>y}
# 	freqArr.push(myHash)
# }
# freqArr = freqArr.sort_by {|hsh| hsh["freq"]}

# freqArr.each{|x|
# 	if x["freq"] >= 2
# 		if x["label"] != "Sin definir"
# 			countyName = x["label"]
# 			myCounties = County.where(:name=>countyName)
# 			myCounties[1..-1].each {|x|
# 				myCounty = x.id
# 				policeName =  "Policía Municipal de "+countyName+ " - "+x.state.name
# 				if Organization.where(:name=>policeName).empty?
# 					Organization.create(:name=>policeName,:county_id=>myCounty)
# 				end
# 			}
# 		end
# 	end
# }


