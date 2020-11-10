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
	{:name=>"Narcomenudista"},
	{:name=>"Sin definir"},
	{:name=>"Jefe operativo"},	
	{:name=>"Jefe regional u operador"}	
]

criminalRoles.each{|role|
	if Role.where(role).empty?
		Role.create(role)
	end
	Role.where(role).last.update(:criminal=>true)
}

unless Role.where(:name=>"Extorsionador").empty?
	Role.where(:name=>"Extorsionador").last.update(:name=>"Extorsionador-narcomenudista")
end

unless Role.where(:name=>"Traficante de droga").empty?
	Role.where(:name=>"Traficante de droga").last.update(:name=>"Traficante o distribuidor")
end