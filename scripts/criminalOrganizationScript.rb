rawData = "1,31/06/20,Cártel del Pacífico-Cártel de Sinaloa ,CDP-CDS,Cártel ,,,Cártel de Guadalajara,,,1,1,1,1,1,1,,,1,1,1,1,,,,1
2,31/06/20,Cártel Jalisco Nueva Generación ,CJNG,Cártel ,,,Cártel del Milenio (organización criminal de la familia Valencia),,,1,1,1,1,1,1,,,,1,1,1,,,,
3,31/06/20,Cárteles Unidos ,CU,Mafia,Célula,Cártel del Pacífico-Cártel de Sinaloa ,Los Talibanes,Cártel del Pacífico-Cártel de Sinaloa ,Cártel Jalisco Nueva Generación,1,1,1,,,,,,,,,,,,,
4,3/31/2020,Los Ciclones,,Mafia ,Escisión,,Cártel del Golfo ,,,1,1,1,,,,,,,,,,,,,
5,3/31/2020,La Oficina,,Banda,Brazo armado,Organización criminal de la familia Meza Flores,Organización criminal de Los Beltrán Leyva,Cártel Jalisco Nueva Generación ,,1,1,,,,,,,,,,,,,,
6,3/31/2020,Los Gloria,,Banda,Pandilla,,,,Cártel Jalisco Nueva Generación; Cártel del Pacífico-Cártel de Sinaloa ,,1,1,,,,,1,,1,,,,,,
7,31/06/20,La Línea,,Mafia,Escisión,Nuevo Cártel de Juárez ,Cártel de Juárez (organización criminal de la familia Carrillo Fuentes),,,1,,,,,,,,,,,,,,,
8,31/06/20,El 30,,Banda,Brazo armado,Cártel del Pacífico-Cártel de Sinaloa ,La Oficina,Cártel del Pacífico-Cártel de Sinaloa;Cárteles Unidos,Cártel Jalisco Nueva Generación,1,1,1,,,,,,,,,,,,,
9,31/06/20,Famila González Valencia (Los Cuinis),,Mafia,Célula,Cártel Jalisco Nueva Generación,Cártel del Milenio (organización criminal de la familia Valencia),Cártel Jalisco Nueva Generación ,,,,,,,,,,,,1,,,,,
10,31/06/20,XXXV,,Banda,Pandilla,,,,,,,,,,,,,,,,,1,,,
11,31/06/20,Los Monkikis,,Banda ,Pandilla,,,,,,1,,,,,,,,,,,,,,
12,31/06/20,Cártel de Tijuana Nueva Generación,CTNG,Mafia,Célula,Cártel Jalisco Nueva Generación,Cártel Jalisco Nueva Generación; Cártel de Los Arellano Félix-Cártel de Tijuana,,Cártel del Pacífico-Sinaloa; Cártel de Los Arellano Félix-Cártel de Tijuana,1,1,,,,,,,,,,,,,,
13,31/06/20,Familia Arzate (Los Arzate),,Mafia,Célula,Cártel del Pacífico-Cártel de Sinaloa ,Cártel del Pacífico-Cártel de Sinaloa ,,Cártel de Los Arellano Félix-Cártel de Tijuana; Cártel Jalisco Nueva Generación,1,1,,,,,,,,,,,,,,
14,31/06/20,Cártel de Los Arellano Félix-Cártel de Tijuana,CAF-CT,Mafia,,,Cártel de Guadalajara,Organización criminal de la familia Meza Flores,Cártel del Pacífico-Sinaloa; Cártel Jalisco Nueva Generación,1,1,,,,,,,,1,1,,,,,
15,31/06/20,Organización criminal de la familia Meza Flores,,Mafia,,,Organización criminal de Los Beltrán Leyva,Cártel de Los Arellano Félix-Cártel de Tijuana,Cártel del Pacífico-Cártel de Sinaloa,1,,,,,,,,,,,,,,,
16,31/06/20,Cártel de Santa Rosa de Lima,SRL,Mafia,,,Los Zetas,,Cártel Jalisco Nueva Generación,1,,,,,,,,,,,,,,,
17,31/06/20,Los Pilotos,,Banda,Brazo armado,Cártel de Los Arellano Félix-Cártel de Tijuana,Cártel de Los Arellano Félix-Cártel de Tijuana,Organización criminal de la familia Meza Flores,Cártel Jalisco Nueva Generación; Cártel del Pacífico-Cártel de Sinaloa,1,1,1,,,,,,,,,,,,,
18,31/06/20,Los Venados,,Banda,Brazo armado,Familia Arzate (Los Arzate),,Cártel del Pacífico-Cártel de Sinaloa ,Cártel de Los Arellano Félix-Cártel de Tijuana; Cártel Jalisco Nueva Generación,1,1,,,,,,,1,1,,,,,,
19,31/06/20,Los Mudos,,Banda ,Pandilla,,,,,,1,,,,,,,,,,,,,,"

divisions = [
	{:slot=>10,:scian3=>981,:name=>"Narcotráfico"},
	{:slot=>11,:scian3=>982,:name=>"Narcomenudeo"},
	{:slot=>12,:scian3=>983,:name=>"Extorsión"},
	{:slot=>13,:scian3=>984,:name=>"Mercado Ilícito de Hidrocarburos"},
	{:slot=>14,:scian3=>985,:name=>"Trata y tráfico de personas"},
	{:slot=>15,:scian3=>986,:name=>"Tráfico de armas"},
	{:slot=>16,:scian3=>987,:name=>"Robo de ferrocarril"},
	{:slot=>17,:scian3=>988,:name=>"Robo de transportistas"},
	{:slot=>18,:scian3=>989,:name=>"Tala clandestina"},
	{:slot=>19,:scian3=>991,:name=>"Contrabando de mercancías"},
	{:slot=>20,:scian3=>992,:name=>"Lavado de dinero"},
	{:slot=>21,:scian3=>993,:name=>"Actos de terrorismo"}
]

organizationArr = []
rawData.each_line{|l| line = l.split(","); organizationArr.push(line)}
organizationArr.each{|x|x.each{|y|y.strip!}}
organizationArr.each{|x|
	if Organization.where(:name=>x[2]).empty?
		print "NEW ORGANIZATION :" + x[2]
		Organization.create(:legacy_id=>x[0].to_i,:name=>x[2],:acronym=>x[3],:league=>x[4],:subleague=>x[5])
	end
	targetOrganization = Organization.where(:name=>x[2]).last
	divisions.each{|y|
		myDivision = Division.where(:scian3=>y[:scian3]).last
		if x[y[:slot]] == "1"
			print "ACITVITY HIT!!!"
			targetOrganization.divisions << myDivision
		end
	}
}



