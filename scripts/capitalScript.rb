rawData2 = "1,1,Aguascalientes,1001,1,Aguascalientes,1
13,2,Mexicali,2002,3,Mexicali,1
19,3,La Paz,3003,,,1
23,4,Campeche,4002,,,1
62,5,Saltillo,5030,5,Saltillo,1
72,6,Colima,6002,8,Colima-Villa de Álvarez,1
180,7,Tuxtla Gutiérrez,7101,10,Tuxtla Gutiérrez,1
217,8,Chihuahua,8019,12,Chihuahua,1
279,9,Cuauhtémoc,9015,13,Valle de México,1
286,10,Durango,10005,,,1
335,11,Guanajuato,11015,,,1
395,12,Chilpancingo de los Bravo,12029,,,1
495,13,Pachuca de Soto,13048,18,Pachuca,1
570,14,Guadalajara,14039,21,Guadalajara,1
762,15,Toluca,15106,24,Toluca,1
834,16,Morelia,16053,25,Morelia,1
901,17,Cuernavaca,17007,28,Cuernavaca,1
944,18,Tepic,18017,30,Tepic,1
986,19,Monterrey,19039,31,Monterrey,1
1065,20,Oaxaca de Juárez,20067,32,Oaxaca,1
1682,21,Puebla,21114,34,Puebla-Tlaxcala,1
1799,22,Querétaro,22014,36,Querétaro,1
1807,23,Othón P. Blanco,23004,,,1
1842,24,San Luis Potosí,24028,38,San Luis Potosí - Soledad de Graciano Sánchez,1
1878,25,Culiacán,25006,,,1
1920,26,Hermosillo,26030,,,1
1966,27,Centro,27004,41,Villahermosa,1
2020,28,Victoria,28041,,,1
2055,29,Tlaxcala,29033,46,Tlaxcala-Apizaco,1
2169,30,Xalapa,30087,48,Xalapa,1
2344,31,Mérida,31050,55,Mérida,1
2456,32,Zacatecas,32056,56,Zacatecas-Guadalupe,1"

# Test

capitalArr = []
rawData2.each_line{|l| line = l.split(","); capitalArr.push(line)}
capitalArr.each{|x|x.each{|y|y.strip!}}
capitalArr.each{|x|
	myCode = x[3].to_i
	myCode = myCode + 100000
	myCode = myCode.to_s
	myCode = myCode[1..-1]
	capital = County.where(:full_code=>myCode).last
	myState = State.where(:code=>myCode[0,2]).last
	myState.update(:capital_id=>capital.id)
	print myState.capital.name
}

