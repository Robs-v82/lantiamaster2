require 'pp'
print "HOLA"
m = Organization.where(:acronym=>"SEMAR").last.detainees
quarters = [
"2019_Q3",
"2019_Q4",
"2020_Q1",
"2020_Q2",
"2020_Q3",
"2020_Q4",
"2021_Q1"
]
myArr = []
quarters.each{|q|
	d = Quarter.where(:name=>q).last.detainees
	x = m.merge(d)
	myHash = {:name=>q, :total=>d.length, :freq=>x.length}
	myArr.push(myHash)
}

pp myArr




