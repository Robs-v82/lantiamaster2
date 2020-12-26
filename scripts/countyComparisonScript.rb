bigCounties = County.where("population > ?",100000)
bigCounties.each{|county|
	myArr = []
	otherCounties = County.where("population > ?",100000)
	otherCounties.each{|other|
		x = (county.towns.where(:name=>"Sin definir").last.latitude - other.towns.where(:name=>"Sin definir").last.latitude).abs()
		y = (county.towns.where(:name=>"Sin definir").last.longitude - other.towns.where(:name=>"Sin definir").last.longitude).abs()
		distance = x + y
		otherHash = {:name=> other.name, :key=>other.id, :distance=>distance}
		myArr.push(otherHash)
	}
	myArr = myArr.sort_by{|row| row[:distance]}
	keyArr = []
	myArr[1,4].each{|row|
		keyArr.push(row[:key])
	}
	print myArr
	print keyArr
	county.update(:comparison=>keyArr)
}