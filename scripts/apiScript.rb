myHash = {}

# LAST UPDATE
lastKilling = Killing.all.sort_by{|k| k.event.event_date}.last
thisMonth = Event.find(lastKilling.event_id).month
lastDay = Event.find(lastKilling.event_id).event_date

myHash[:lastUpdate] = Date.civil(lastDay.year, lastDay.month, -1)

# TOTAL VICTIMS PER YEAR (WITH ESTIMATE FOR CURRENT YEAR)
myYears = helpers.get_regular_years
thisYear = Year.where(:name=>Time.now.year.to_s).last
victimYearsArr = []
myYears.each{|year|
    yearHash = {}
    yearHash[:year] = year.name.to_i
    if year != thisYear
        yearHash[:victims] = year.victims.length
        yearHash[:estimate] = false
    else
        n = helpers.get_specific_months([thisYear], "victims").length
        unless n == 0
            yearHash[:victims] = year.victims.length*(12/n)
            if n == 12
                yearHash[:estimate] = false        
            else
                yearHash[:estimate] = true
            end
        end
    end
    victimYearsArr.push(yearHash)
}
myHash[:years] = victimYearsArr

# MONTHLY VICITMS FOR 5 MOST VIOLENT STATE (PREVIOUS 12 MONTHS) 
topStatesArr = []
State.all.each{|state|
    stateHash = {}
    stateHash[:code] = state.code
    stateHash[:name] = state.name
    stateHash[:shortname] = state.shortname
    r = 11..0
    stateHash[:totalVictims] = 0
    stateHash[:months] = []
    localVictims = state.victims
    (r.first).downto(r.last).each {|x|
        monthHash = {}
        monthHash[:month] = (thisMonth.first_day - (x*28).days).strftime('%m-%Y')
        monthHash[:victims] = Month.where(:name=>(thisMonth.first_day - (x*28).days).strftime('%Y_%m')).last.victims.merge(localVictims).length
        stateHash[:totalVictims] += monthHash[:victims]
        stateHash[:months].push(monthHash)
    }
    topStatesArr.push(stateHash)
}
topStatesArr = topStatesArr.sort_by{|state| -state[:totalVictims]}
myHash[:topStates] = topStatesArr[0..4]

Cookie.create(:data=>myHash, :category=>"api")

