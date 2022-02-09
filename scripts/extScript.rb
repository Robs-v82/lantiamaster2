x = Division.where(:name=>"Extorsión").last.organizations

myArr = [] 

x.each{|racket|
	if racket.counties.length > 12
		
		myArr.push(racket.name)
	end
}

print myArr