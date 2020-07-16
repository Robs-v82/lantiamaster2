# CODE TO GET COMMON DOMAINS
urls = Source.pluck(:url)
short_urls = []
urls.each {|u|
	short_urls.push(u[0,22])
}
keyArr = short_urls.uniq

finalArr = []

keyArr.each {|x|
	myHash = {}
	y = short_urls.count(x)
	myHash = {"label"=>x,"freq"=>y}
	finalArr.push(myHash)
}

finalArr = finalArr.sort_by {|hsh| hsh["freq"]}

require 'pp'
pp finalArr
print "NÚMERO DE REGISTROS "
print finalArr.length

rawData = "uniradioinforma.com,50,Uniradio Informa,02
ensenada.net,28,Ensenada.net,02
afntijuana.info,24,Agencia Fronteriza de Noticias,02
elsoldetijuana.com.mx,22,El Sol de Tijuana,02
el-mexicano.com.mx,20,El Mexicano,02
letraroja.com,69,Letra Roja,09
la-prensa.com.mx,57,La Prensa,09
busquedas.gruporeforma.com,26,Grupo Reforma,09
milenio.com,20,Milenio,09
la-prensa.com.mx,12,La Prensa,09
pasala.com.mx,11,Pásala,09
vorticemx.com,1,Vórtice,07
entrelineas.com.mx,53,Entrelíneas,08
elheraldodejuarez.com.mx,42,El Heraldo de Juárez,08
laopcion.com.mx,31,La Opción,08
eldiariodecoahuila,12,El Diario de Coahuila,05
elsiglodetorreon,9,El Siglo de Torreón,05
informatelaguna.com,7,Infórmate Laguna,05
colimanoticias.com,37,Colima Noticias,06
edomex.quadratin.com.mx,37,Quadratín Edomex,15
cuestiondepolemica.com,9,Cuestión de Polémica,15
periodicocorreo.com.mx,251,Periódico Correo,11
agenciairza.com,20,Agencia Irza,12
sintesisdeguerrero.com,20,Síntesis de Guerrero,12
digitalguerrero.com.mx,10,Digital Guerrero,12
agenciairza.com,10,Agencia Irza,12
agenciairza.com,10,Agencia Irza,12
agenciairza.com,9,Agencia Irza,12
novedadesaca.mx,8,Novedades Acapulco,12
agenciairza.com,5,Agencia Irza,12
novedadesaca.mx,4,Novedades Acapulco,12
agenciairza.com,4,Agencia Irza,12
novedadesaca.mx,4,Novedades Acapulco,12
agenciairza.com,3,Novedades Acapulco,12
agenciairza.com,3,Agencia Irza,12
agenciairza.com,2,Agencia Irza,12
novedadesaca.mx,2,Novedades Acapulco,12
criteriohidalgo.com,19,Criterio,13
notisistema.com,44,Notisistema,14
jaliscorojo.com,33,Jalisco Rojo,14
lavozdemichoacan.com.mx,129,La Voz de Michoacán,16
reportemichoacan.com.mx,41,Reporte Michoacán,16
launion.com.mx,61,La Unión de Morelos,17
oaxacadiaadia.com,26,Oaxaca Día a Día,20
e-consulta.com,39,e-consulta,21
pueblaroja.mx,13,Puebla Roja,21
noticaribe.com.mx,52,Noticaribe,23
codigosanluis.com,21,Código San Luis,24
pulsoslp.com.mx,19,Pulso,24
agenciadenoticiasslp.com,10,Agencia de Noticias,24
lineadirectaportal.com,83,Línea Directa,25
elsoldesinaloa.com,20,El Sol de Sinaloa,25
opinionsonora.com,67,Opinión Sonora,26
elheraldodetabasco.com.mx,19,El Heraldo de Tabasco,27
valorportamaulipas.com.mx,49,Valor por Tamaulipas,28
e-tlaxcala.mx,13,e-consulta Tlaxcala,29
vanguardiaveracruz.mx,55,Vanduardia de Veracruz,30
e-veracruz.mx,21,e-consulta Veracruz,30
laverdadnoticias.com,10,La Verdad,31
ntrzacatecas.com,41,NTR,32
zacatecasonline.com.mx,15,Zacatecas Online,32
novedadesaca.mxnovedadesaca.mx,7,Novedades Acapulco,12
novedadesaca.mx,7,Novedades Acapulco,12
elsoldezacatecas.com.mx,7,El sol de Zacatecas,32
tribunacampeche.com,6,Tribuna,03
contextodedurango.com.mx,6,Contexto de Duranto,10
tolucanoticias.com,6,Toluca Noticias,15
hoyestado.com,5,Hoy Estado,15
pagina24.com.mx,4,Página 24,01
enfoqueinformativo.mx,4,Enfoque Informativo,12
elsoldenayarit.mx,3,El Sol de Nayarit,18
adnsureste.info,3,ADN Sureste,20
diariodequeretaro.com.mx,3,Diario de Querétaro,22
adninformativo.mx,3,ADN Informativo,22
elsoldetlaxcala.com.mx,3,El Sol de Tlaxcala,29
60minutos.info,3,60 Minutos,30
bcsnoticias.mx,2,BCS Noticias,03
jornada.com.mx,2,La Jornada,09
oaxaca.eluniversal.com.mx,2,El Universal Oaxaca,20
periodicocentral.mx,2,Periódico Central,21
notinfomex.mx,2,Notinfomex,30
latarde.com.mx,2,La Tarde de Reynosa,28
heraldo.mx,1,El Heraldo de Aguascalientes,01
noreste.net,1,Noreste,30
valorportamaulipas.info,1,Valor por Tamaulipas,28
ignaciomartinez.com.mx,1,IM Noticias,16
alinstantenoticias.com,1,Alinstante Noticias,25
lorealdeguerrero.com,1,Lo Real de Guerrero,12
laznoticias.info,1,La Z Noticias,16
vivalanoticia.mx,1,Viva la Noticia,25
proceso.com.mx,1,Proceso,09
verticediario.com,1,Vértice,12
mimorelia.com,1,Mi Morelia.com,16
guerrero.quadratin.com.mx,1,Quadratín Guerrero,12
info7.mx,1,Info 7,19
sinembargo.mx,1,Sinembargo,09
animalpolitico.com,1,Animal Político,09
diariobasta.com,1,Diario Basta,05
multimedios.com,1,Canal 6,09
noticel.mx,1,Noticel,14
mural.com,1,Mural,14"

media_division = Division.find(173)
mediaArr = []
rawData.each_line{|l| line = l.split(","); mediaArr.push(line)}
mediaArr.each{|x|x.each{|y|y.strip!}}
mediaArr.each{|x|
	my_county_id = State.where(:code=>x[3]).last.counties.last.id
	if Organization.where(:domain=>x[0]).length == 0
		Organization.create(:county_id=>my_county_id, :name=>x[2], :domain=>x[0])
		Organization.last.divisions << media_division
	end
}