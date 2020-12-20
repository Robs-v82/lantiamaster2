
allCartels = Sector.where(:scian2=>98).last.organizations.uniq
allCartels = allCartels.pluck(:name)
myCartels = [
	"Banda de El Toñín",
	"Banda de la Zona Norte",
	"Cártel de San Luis Potosí Nueva Generación",
	"Cártel de Sinaloa",
	"Cártel del Noreste",
	"Cártel Jalisco Nueva Generación",
	"Cártel Tijuana Nueva Generación",
	"Cártel Zicuirán Nueva Generación",
	"Cárteles Unidos",
	"Gente Nueva",
	"Grupo Delta",
	"Grupo Élite",
	"La Unión Tepito",
	"La Unión Tepito Nueva Generación",
	"Los Artistas Asesinos",
	"Los Arzate",
	"Los Cabos",
	"Los Chapitos",
	"Los Cuinis",
	"Los Guerrero",
	"Los Jaguares",
	"Los Mexicles",
	"Los Paéz",
	"Los Paredes",
	"Los Piña",
	"Los RR",
	"Los Salazar",
	"Los Salgueiro",
	"Los Siete Demonios",
	"Los Sinaloas",
	"Los Venados",
	"Nuevo Cártel del Tigre",
	"Tropa del Infierno"
]
missingCartels = []
myCartels.each{|cartel|
	unless allCartels.include? cartel
		missingCartels.push(cartel)
	end
}
print missingCartels