myQuarter = Quarter.where(:name=>"2019_Q4").last
evolution_score = []
    [7,6,5,4,3,2,1,0].each{|x|
    t = (myQuarter.first_day - (x*90).days).strftime('%m-%Y')
    Quarter.all.each{|q|
        if (q.first_day.strftime('%m-%Y')) == t
            evolution_score.push(q.name)
        end
    } 
    # this_quarter = Quarter.find(id-x)
    # periodString = quarter_strings(this_quarter)
    # periodString = periodString[:quarterShort]+"/"+this_quarter.name[0..3]
    # this_quarter_score = this_quarter_ispyv(this_quarter, state)
    # periodArr = [periodString,this_quarter_score]
    # evolution_score.push(periodArr)
}
print evolution_score