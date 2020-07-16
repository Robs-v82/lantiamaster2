rawData = "Aguascalientes,Ags,01,1405625
Baja California,BC,02,3550079
Baja California Sur,BCS,03,779726
Campeche,Camp,04,975685
Coahuila,Coah,05,3153984
Colima,Col,06,766595
Chiapas,Chis,07,5605965
Chihuahua,Chih,08,3746865
Ciudad de México,CDMX,09,9036958
Durango,Dgo,10,1844737
Guanajuato,Gto,11,6145872
Guerrero,Gro,12,3636993
Hidalgo,Hgo,13,3032650
Jalisco,Jal,14,8282892
México,Mex,15,17152777
Michoacán,Mich,16,4775052
Morelos,Mor,17,2011648
Nayarit,Nay,18,1261525
Nuevo León,NL,19,5494283
Oaxaca,Oax,20,4109069
Puebla,Pue,21,6511015
Querétaro,Qro,22,2218638
Quintana Roo,QR,23,1664973
San Luis Potosí,SLP,24,2835651
Sinaloa,Sin,25,3117935
Sonora,Son,26,3019006
Tabasco,Tab,27,2530298
Tamaulipas,Tamps,28,3605885
Tlaxcala,Tlax,29,1356078
Veracruz,Ver,30,8462063
Yucatán,Yuc,31,2221105
Zacatecas,Zac,32,1648541"
stateArr = []
rawData.each_line{|l| line = l.split(","); stateArr.push(line)}
stateArr.each{|x|x.each{|y|y.strip!}}
stateArr.each{|x| State.create(name:x[0], shortname:x[1], code:x[2], population:x[3])}
