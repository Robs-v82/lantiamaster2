criminalRoles = [
	{:name=>"Líder"},
	{:name=>"Operador"},
	{:name=>"Autoridad cooptada"},
	{:name=>"Jefe de sicarios"},
	{:name=>"Sicario"},
	{:name=>"Jefe de plaza"},
	{:name=>"Jefe de célula"},
	{:name=>"Extorsionador"},
	{:name=>"Secuestrador"},
	{:name=>"Traficante de droga"},
	{:name=>"Narcomenudista"}
]

criminalRoles.each{|role|
	if Role.where(role).empty?
		Role.create(role)
	end
	Role.where(role).last.update(:criminal=>true)
}