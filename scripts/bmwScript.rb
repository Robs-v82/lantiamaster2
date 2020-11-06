require 'pp'
table = []
s = State.where(:code=>"16").last.leads.where.not(:category=>"Presencia registrada en medios")
m = Month.where(:name=>"2020_01").last.leads.where.not(:category=>"Presencia registrada en medios")
# myLeads = myLeads.where.not(:category=>"Presencia registrada por autoridades")
myLeads = s.merge(m)
myLeads.each{|lead|
	leadArr = []
	myDate = lead.event.event_date
	leadArr.push(myDate)
	leadArr.push(lead.event.town.county.name)
	leadArr.push(lead.event.organization.name)
	leadArr.push(lead.category)
	table.push(leadArr)
}
pp table

headers = %w{DATE MUNICIPALITY ORGANIZATION TYPE}

myFile = 'public/leads_mich.csv'

CSV.open(myFile, 'w:UTF-8', write_headers: true, headers: headers) do |writer|
	table.each do |record|
		writer << record
	end
end