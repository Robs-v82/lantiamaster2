# ADD ENSU
mainFolder = "uploads/"
quarters = Quarter.all
quarters.each {|q|
	q.ensu.purge
	myFolder = "ensu/"
	myFile = mainFolder+"ENSU_percepción - "+q.name+".csv"
	q.ensu.attach(myFile)
}

