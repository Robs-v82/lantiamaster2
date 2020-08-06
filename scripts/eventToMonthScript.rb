Event.all.each{|event|
	if event.event_date
		target = event.event_date.strftime("%Y_%m")
		myMonth = Month.where(:name=>target).last.id
		event.update(:month_id=>myMonth)
	end
}