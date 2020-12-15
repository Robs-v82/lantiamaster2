Victim.destroy_all
Killing.destroy_all
Event.all.each{|event|
	if event.detentions.empty? && event.leads.empty?
		event.sources.destroy_all
		event.destroy
	end
}

Cookie.all.each{|cookie|
	unless cookie.category.nil?
		if cookie.category.include? "victim"
			cookie.destroy
		end
	end
}