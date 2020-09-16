government = Division.where(:scian3=>931).last

# CREATE A POLICE DEPARTMENT FOR EACH STATE
State.all.each{|state|
	
	# CREATE STATE POLICE DEPARTMENTS
	policeName = "Policía Estatal de "+state.name
	if Organization.where(:name=>policeName).empty?
		Organization.create(:name=>policeName)
		myOrganization = Organization.last
	else
		myOrganization = Organization.where(:name=>policeName).last
	end
	myCode = state.code+"000"
	myCounty = County.where(:full_code=>myCode).last.id
	myOrganization.update(:league => "Seguridad Pública", :county_id => myCounty)
	unless myOrganization.divisions.include? (government)
		myOrganization.divisions << government
	end 

	# CREATE STATE JUSTICE DEPARTMENTS
	justiceName = "Fiscalía General de Justicia de "+state.name
	if Organization.where(:name=>justiceName).empty?
		Organization.create(:name=>justiceName)
		myOrganization = Organization.last
	else
		myOrganization = Organization.where(:name=>justiceName).last
	end
	myCode = state.code+"000"
	myCounty = County.where(:full_code=>myCode).last.id
	myOrganization.update(:league => "Procuración de Justicia", :county_id => myCounty)
	unless myOrganization.divisions.include? (government)
		myOrganization.divisions << government
	end 
}

County.where.not(:name=>"Sin definir").each {|county|

	# CREATE COUNTY POLICE DEPARTMENTS
	if County.where(:name=>county.name).length == 1
		policeName = "Policía Municipal de "+county.name
	else
		policeName = "Policía Municipal de "+county.name+" - "+county.state.shortname
	end
	if Organization.where(:name=>policeName).empty?
		Organization.create(:name=>policeName)
		myOrganization = Organization.last
	else
		myOrganization = Organization.where(:name=>policeName).last
	end
	myOrganization.update(:league => "Seguridad Pública", :county_id => county.id)
	unless myOrganization.divisions.include? (government)
		myOrganization.divisions << government
	end 
}

nationalAgencies = [
	{:name=>"Secretaría de la Defensa Nacional" , :acronym=>"SEDENA", :league=>"Fuerzas Armadas"},
	{:name=>"Secretaría de Marina", :acronym=>"SEMAR", :league=>"Fuerzas Armadas"},
	{:name=>"Policía Federal", :acronym=>"PF", :league=>"Seguridad Pública"},
	{:name=>"Guardia Nacional", :acronym=>"GN", :league=>"Seguridad Pública"},
	{:name=>"Fiscalía General de la República", :acronym=>"FGR", :league=>"Procuración de Justicia"},
]

nationalAgencies.each{|agency|
	myName = agency[:name]
	if Organization.where(:name=>myName).empty?
		Organization.create(agency)
		myOrganization = Organization.last
	else
		myOrganization = Organization.where(:name=>myName).last
		myOrganization.update(agency)
	end
	unless myOrganization.divisions.include? (government)
		myOrganization.divisions << government
	end 
}




