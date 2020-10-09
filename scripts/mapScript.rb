require 'json'
def depth (a)
  return 0 unless a.is_a?(Array)
  return 1 + depth(a[0])
end
State.all.each{|state|
	x = state.code
	json = File.read('public/maps/'+x+'.geojson')
	data =  JSON.parse(json)
	data['features'].each{|county|
		properties = county['properties']
		myState = State.where(:code=>properties['CVE_ENT']).last
		myCounty = myState.counties.where(:code=>properties['CVE_MUN']).last
		if properties['clave_munici']
			properties['full_code'] = properties['clave_munici']
			properties.delete('clave_munici')
		else
			properties['full_code'] = myCounty.full_code
		end
		properties[:name] = myCounty.shortname
		geometry = county['geometry']
		coordinates = geometry['coordinates']
	}
	object = data.to_json
	File.open('public/maps/'+x+'.geojson', 'w:UTF-8') { |f| f.write object }
	print " **************"
	print state.name
	print " READY! "
}

