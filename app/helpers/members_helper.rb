module MembersHelper
	def detention_cartels
		Organization.where(:name=>"Cártel de Sinaloa")
		.or(Organization.where(:name=>"Cártel Jalisco Nueva Generación"))
		.or(Organization.where(:name=>"Cártel del Noreste"))
		.or(Organization.where(:name=>"La Unión Tepito"))
	end

	def top_detention_roles
		myArr = [
			"Líder",
			"Autoridad cooptada",
			"Jefe de célula",
			"Traficante o distribuidor",
			"Jefe regional u operador",
		]
		return myArr
	end
end
