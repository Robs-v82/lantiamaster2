# rawData = "02,Marina del Pilar,Ávila,Olmeda,gobernador02.jpg
# 	03,Víctor,Castro,Cosio,gobernador03.jpg
# 	04,Layda,Sansores,San Román,gobernador04.jpg
# 	08,María Eugenia,Campos,Galván,gobernador08.jpg
# 	06,Indira,Vizcaíno,Silva,gobernador06.jpg
# 	12,Evelyn,Salgado,Pineda,gobernador12.jpg
# 	16,Alfredo,Ramírez,Bedolla,gobernador16.jpg
# 	18,Miguel Ángel,Navarro,Quintero,gobernador18.jpg
# 	22,Mauricio,Kuri,González,gobernador22.jpg
# 	24,Ricardo,Gallardo,Cardona,gobernador24.jpg
# 	25,Rubén,Rocha,Moya,gobernador25.jpg
# 	26,Alfonso,Durazo,Montaño,gobernador26.jpg
# 	29,Lorena,Cuéllar,Cisneros,gobernador29.jpg"

rawData = "01,María Teresa,Jiménez,Esquivel,gobernador01.jpg
10,Esteban,Villegas,Villareal,gobernador10.jpg
28,Américo,Villarreal,Anaya,gobernador28.jpg
09,Martí,Batres,Guadarrama,gobernador09.jpg
21,Sergio,Céspedes,Peregrina,gobernador21.jpg
23,Mara,Lezama,Espinosa,gobernador23.jpg
20,Salomón,Jara,Cruz,gobernador20.jpg
07,Rutilio,Escandón,Cadenas,gobernador07.jpg
27,Carlos Manuel,Merino,Campos,gobernador27.jpg
32,David,Monreal,Ávila,gobernador32.jpg
13,Julio,Menchaca,Salazar,gobernador13.jpg"

if Role.where(:name=>"Gobernador").empty?
	Role.create(:name=>"Gobernador")	
end
governorKey = Role.where(:name=>"Gobernador").last.id

governorArr = []
rawData.each_line{|l| line = l.split(","); governorArr.push(line)}
governorArr.each{|x|x.each{|y|y.strip!}}

State.all.each{|state|
	myName = "Gubernatura de "+state.name
	myCode = state.code+"000"
	myCounty = County.where(:full_code=>myCode).last.id
	if Organization.where(:name => myName).empty?
		Organization.create(:name => myName, :league => "CONAGO", :county_id => myCounty)
	end
	government = Division.where(:scian3=>931).last
	Organization.last.divisions << government
	}

# UPATE GOVERNORS' INFORMATION
State.all.each{|state|
	myName = "Gubernatura de "+state.name
	organization_id = Organization.where(:name => myName).last.id
	stateMembers = Organization.where(:name => myName).last.members
	governor = stateMembers.where(:role_id=>governorKey).last
	governorArr.each{|x|
		filename = "gobernador"+x[1]+".jpg"
		downloaded_image = URI.open(Rails.root / 'app' / 'assets' / 'images' / x[4])
		print filename
		if x[0] == state.code
			if governor == nil	
				Member.create(
					:firstname => x[1],
					:lastname1 =>  x[2],
					:lastname2 => x[3],
					:organization_id => organization_id,
					:role_id => governorKey
				)
				member.last.avatar.attach(io: downloaded_image, filename: filename)
			else
				governor.update(
					:firstname => x[1],
					:lastname1 =>  x[2],
					:lastname2 => x[3],
				)
				governor.avatar.purge
				governor.avatar.attach(io: downloaded_image, filename: filename)
			end
		end
	}		
	
}

# testUpdate