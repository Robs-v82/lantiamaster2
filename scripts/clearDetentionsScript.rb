Detention.all.each{|i|
	i.detainees.destroy_all
	i.destroy
}
oldRoles = ["Líder", "Operador", "Autoridad cooptada", "Jefe de sicarios", "Sicario", "Jefe de plaza", "Jefe de célula", "Extorsionador", "Secuestrador", "Traficante de droga", "Narcomenudista"]
oldRoles.each{|role|
	unless Role.where(:name=>role).empty?
		Role.where(:name=>role).last.destroy
	end
}
myArr = ["Autoridad cooptada", "Jefe de plaza", "Jefe regional u operador", "Jefe de sicarios", "Traficante o distribuidor", "Sicario", "Jefe operativo", "Extorsionador-narcomenudista", "Sicario", "Líder", "Jefe de célula", "Jefe regional","Otro"]
myArr.each{|role|
	Role.create(:name=>role, :criminal=>true)
}