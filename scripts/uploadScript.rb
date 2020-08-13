# ADD ENSU
mainFolder = "uploads/"
quarters = Quarter.all

quarters.each {|q|
	q.ensu.purge
	myFolder = "ensu/"
	myFile = mainFolder+"ENSU_percepción - "+q.name+".csv"
	q.ensu.attach(myFile)
}

# ADD VIOLENCE REPORT
months = Month.all
months.each {|m|
	m.violence_report.purge
	myFolder = "Rpoertes Lantia/"
	myFile
}