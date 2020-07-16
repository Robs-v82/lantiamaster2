module ApplicationHelper

	def get_years
		myArr = []
		target = Event.pluck(:event_date).uniq
		n = target.length - 1
		myRange = (1..n)
		myRange.each{|x|
			myArr.push(target[x].year)
		}
		myYears = myArr.uniq
		return	myYears
	end

	def get_months(year)
		myArr = []
		target = Event.where(("CAST(strftime('%Y', event_date) as INT) = ?"), year)
		target = target.pluck(:event_date).uniq
		target = target.sort
		n = target.length - 1
		myRange = (1..n)
		myRange.each{|x|
			myMonth = target[x].strftime("%m")
			# myMonth = I18n.l(target[x], :format=> "%B") 
			myArr.push(myMonth)
		}
		myMonths = myArr.uniq
		return	myMonths
	end

	def get_time_span(month,year)
		monthArr = ["04","06","09","11"]
		if month == ""
			time_span = (year+"-01-01"..year+"-12-31")
		elsif month == "02"
			time_span = (year+"-"+month+"-01"..year+"-"+month+"-28")
		elsif monthArr.include? month
			time_span = (year+"-"+month+"-01"..year+"-"+month+"-30")
		else
			time_span = (year+"-"+month+"-01"..year+"-"+month+"-31")	
		end
		return time_span
	end

end
