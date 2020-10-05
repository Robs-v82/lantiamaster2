module EventsHelper

	def lastDay(query)
		if query == "victims"
			lastRecord = Killing.all.sort_by{|k| k.event.event_date}.last
	    end
	    lastDay = Event.find(lastRecord.event_id).event_date
	    lastDay = Date.civil(lastDay.year, lastDay.month, -1)
	    return lastDay
	end

end
