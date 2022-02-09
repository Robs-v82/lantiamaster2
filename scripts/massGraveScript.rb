require 'pp'
require "CSV"
states = State.all
records = []
states.each{|state|
	stateArr = []
	stateArr.push(state.name)
	localVictims = state.victims.length
	stateArr.push(localVictims)
	localKillings = state.killings
	localMass = localKillings.where(:mass_grave=>true)
	counter = 0
	localMass.each{|k|
		counter += k.victims.length
	}
	stateArr.push(counter)
	records.push(stateArr)
}
headers = %w{Estado Total Subtotal}
fileroot = "/Users/Bobsled/documents/massGrave.csv"
print fileroot
pp records
CSV.open(fileroot, 'w:UTF-8', write_headers: true, headers: headers) do |writer|
	records.each do |record|
		writer << record
	end
end
