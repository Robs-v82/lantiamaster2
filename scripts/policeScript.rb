

# CREATE A POLICE DEPARTMENT FOR EACH STATE
State.all.each{|state|
	myName = "Policía Estatal de "+state.name
	myCode = state.code+"000"
	myCounty = County.where(:full_code=>myCode).last.id
	if Organization.where(:name => myName).empty?
		Organization.create(:name => myName, :league => "SEGURIDAD PÚBLICA", :county_id => myCounty)
	end
	government = Division.where(:scian3=>931).last
	Organization.last.divisions << government
}
