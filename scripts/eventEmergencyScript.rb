Event.all.each{|event|
	if event.event_date.nil?
		event.destroy
	end
}