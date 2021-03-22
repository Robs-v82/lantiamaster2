masterArr = []
years = %w{2018 2019 2020}
years.each{|y|
	Year.where(:name=>y).last.quarters.each{|q|
		key = q.name
		myHash = {key=>q.killings.where(:shooting_among_criminals=>true).length}
		masterArr.push(myHash) 
	}
}
print masterArr