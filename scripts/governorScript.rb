require 'open-uri'

rawData = "01,Martín,Orozco,Sandoval,https://envios.conago.org.mx/uploads/imagenes/gobernadores/MartinOrozcoSandoval.jpg
02,Jaime,Bonilla,Valdez,https://envios.conago.org.mx/uploads/imagenes/gobernadores/jaime-bonilla-valdez-baja-california.jpg
03,Carlos,Mendoza,Davis,https://envios.conago.org.mx/uploads/imagenes/gobernadores/CarlosMendozaDavis.jpg
04,Carlos Miguel,Aysa,González,https://envios.conago.org.mx/uploads/imagenes/gobernadores/CarlosMiguelAysaGonzalez.jpg
05,Miguel Ángel,Riquelme,Solís,https://envios.conago.org.mx/uploads/imagenes/gobernadores/Miguel-Angel-Riquelme-Solis.jpg
06,José Ignacio,Peralta,Sánchez,https://envios.conago.org.mx/uploads/imagenes/gobernadores/JoseIgnacioPeraltaSanchez.jpg
07,Rutilio,Cruz Escandón,Cadenas,https://envios.conago.org.mx/uploads/imagenes/gobernadores/Chiapas_RutilioEscandonCruzCadena.jpg
08,Javier,Corral,Jurado,https://envios.conago.org.mx/uploads/imagenes/gobernadores/JavierCorralJurado.jpg
09,Claudia,Sheinbaum,Pardo,https://envios.conago.org.mx/uploads/imagenes/gobernadores/CDMX_claudiasheinbaumpardo.jpg
10,José,Rosas Aispuro,Torres,https://envios.conago.org.mx/uploads/imagenes/gobernadores/JoseRosasAispuroTorres.jpg
11,Diego Sinhue,Rodríguez,Vallejo,https://envios.conago.org.mx/uploads/imagenes/gobernadores/GTO_Diegosinhuerodriguezvallejo.jpg
12,Héctor Antonio,Astudillo,Flores,https://envios.conago.org.mx/uploads/imagenes/gobernadores/HectorAstudilloFlores.jpg
13,Omar,Fayad,Meneses,https://envios.conago.org.mx/uploads/imagenes/gobernadores/OmarFayadMeneses.jpg
14,Enrique,Afaro,Ramírez,https://envios.conago.org.mx/uploads/imagenes/gobernadores/JAL_EnriqueAlfaroRamirez.jpg
15,Alfredo,Del Mazo,Maza,https://envios.conago.org.mx/uploads/imagenes/gobernadores/Alfredo-Del-Mazo-Maza.jpg
16,Silvano,Aureoles,Conejo,https://envios.conago.org.mx/uploads/imagenes/gobernadores/SilvanoAureolesConejo.jpg
17,Cuauhtémoc,Blanco,Bravo,https://envios.conago.org.mx/uploads/imagenes/gobernadores/MOR_CuauhtemocBlancoBravo.jpg
18,Antonio,Echeverría,García,https://envios.conago.org.mx/uploads/imagenes/gobernadores/Antonio-Echevarria-Garcia.jpg
19,Jaime Heliodoro,Rodríguez,Calderón,https://envios.conago.org.mx/uploads/imagenes/gobernadores/JaimeHeliodoroRodriguezCalderon.jpg
20,Alejandro Ismael,Murat,Hinojosa,https://envios.conago.org.mx/uploads/imagenes/gobernadores/AlejandroIsmaelMuratHinojosa.jpg
21,Luis Miguel Gerónimo,Barbosa,Huerta,https://envios.conago.org.mx/uploads/imagenes/gobernadores/MiguelBarbosaHuerta.jpg
22,Francisco,Domínguez,Servién,https://envios.conago.org.mx/uploads/imagenes/gobernadores/FranciscoDominguezServien.jpg
23,Carlos Manuel,Joaquín,González,https://envios.conago.org.mx/uploads/imagenes/gobernadores/CarlosManuelJoaquinGonzalez.jpg
24,Juan Manuel,Carreras,López,https://envios.conago.org.mx/uploads/imagenes/gobernadores/JuanManuelCarrerasLopez.jpg
25,Quirino,Ordaz,Copppel,https://envios.conago.org.mx/uploads/imagenes/gobernadores/QuirinoOrdazCoppel.jpg
26,Claudia Artemiza,Pavlovich,Arellano,https://envios.conago.org.mx/uploads/imagenes/gobernadores/ClaudiaPavlovichArellano.jpg
27,Adán Augusto,López,Hernández,https://envios.conago.org.mx/uploads/imagenes/gobernadores/TAB_AdanAugustoLopezHernandez.jpg
28,Francisco Javier,García,Cabeza de Vaca,https://envios.conago.org.mx/uploads/imagenes/gobernadores/FranciscoJavierGarciaCabezaDeVaca.jpg
29,Marco Antonio,Mena,Rodríguez,https://envios.conago.org.mx/uploads/imagenes/gobernadores/MarcoAntonioMenaRodriguez.jpg
30,Cuitláhuac,García,Jiménez,https://envios.conago.org.mx/uploads/imagenes/gobernadores/VER_CuitlahuacGarciaJimenez2.jpg
31,Mauricio,Vila,Dosal,https://envios.conago.org.mx/uploads/imagenes/gobernadores/YUC_MauricioVilaDosal.jpg
32,Alejandro,Tello,Cristerna,https://envios.conago.org.mx/uploads/imagenes/gobernadores/AlejandroTelloCristerna.jpg"

# CREATE GOVERNOR ROLE
if Role.where(:name=>"Gobernador").empty?
	Role.create(:name=>"Gobernador")	
end
governorKey = Role.where(:name=>"Gobernador").last.id


# CREATE A GOVERNMENT ORGANIZATION FOR EACH STATE
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
	government = Division.find(138)
	Organization.last.divisions << government
	organization_id = Organization.last.id
	governorArr.each{|x|
		if x[0] == state.code
			Member.create(
				:firstname => x[1],
				:lastname1 =>  x[2],
				:lastname2 => x[3],
				:organization_id => organization_id,
				:role_id => governorKey
			)
			filename = x[1]+"_"+x[2]+".jpg"
			downloaded_image = open(x[4])
			Member.last.avatar.attach(io: downloaded_image, filename: filename)
		end
	}
}




