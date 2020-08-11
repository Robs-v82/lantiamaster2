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

compArr = [
{:key=>1,:compare=>[11,14,24,32]},
{:key=>2,:compare=>[3,8,25,26]},
{:key=>3,:compare=>[2,23,25,26]},
{:key=>4,:compare=>[7,23,27,31]},
{:key=>5,:compare=>[8,19,24,28]},
{:key=>6,:compare=>[14,16,18,25]},
{:key=>7,:compare=>[12,20,23,27]},
{:key=>8,:compare=>[2,5,10,26]},
{:key=>9,:compare=>[14,15,17,19]},
{:key=>10,:compare=>[5,8,25,32]},
{:key=>11,:compare=>[16,14,22,24]},
{:key=>12,:compare=>[16,17,20,21]},
{:key=>13,:compare=>[15,21,22,30]},
{:key=>14,:compare=>[9,11,16,19]},
{:key=>15,:compare=>[9,14,19,22]},
{:key=>16,:compare=>[11,12,14,15]},
{:key=>17,:compare=>[9,12,15,21]},
{:key=>18,:compare=>[2,6,14,25]},
{:key=>19,:compare=>[5,9,14,28]},
{:key=>20,:compare=>[7,12,21,30]},
{:key=>21,:compare=>[15,19,20,30]},
{:key=>22,:compare=>[11,13,15,24]},
{:key=>23,:compare=>[3,4,18,32]},
{:key=>24,:compare=>[1,11,19,22]},
{:key=>25,:compare=>[8,10,18,26]},
{:key=>26,:compare=>[2,8,10,25]},
{:key=>27,:compare=>[4,7,20,30]},
{:key=>28,:compare=>[5,19,24,30]},
{:key=>29,:compare=>[13,15,21,30]},
{:key=>30,:compare=>[20,21,27,28]},
{:key=>31,:compare=>[4,7,23,27]},
{:key=>32,:compare=>[1,10,14,24]},
]

compArr.each{|x|
	State.find(x[:key]).update(:comparison=>x[:compare])
}