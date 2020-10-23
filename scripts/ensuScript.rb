stateName = ["Aguascalientes", "Baja California", "Baja California Sur", "Campeche", "Coahuila", "Colima", "Chiapas", "Chihuahua", "Ciudad de México", "Durango", "Guanajuato", "Guerrero", "Hidalgo", "Jalisco", "México", "Michoacán", "Morelos", "Nayarit", "Nuevo León", "Oaxaca", "Puebla", "Querétaro", "Quintana Roo", "San Luis Potosí", "Sinaloa", "Sonora", "Tabasco", "Tamaulipas", "Tlaxcala", "Veracruz", "Yucatán", "Zacatecas"]
myCities = [
	["Aguascalientes",["Aguascalientes"]],
	["Baja California",["Mexicali","Tijuana"]],
	["Baja California Sur",["La Paz","Los Cabos1"]],
	["Campeche",["San Francisco de Campeche","Ciudad del Carmen"]],
	["Coahuila",["Saltillo","La Laguna1","La Laguna2","Piedras Negras"]],
	["Colima",["Colima","Manzanillo"]],
	["Chiapas",["Tuxtla Gutiérrez","Tapachula"]],
	["Chihuahua",["Chihuahua","Juárez"]],
	["Ciudad de México",["Norte2","Sur3","Oriente4","Poniente5","Norte3","Sur4","Oriente5","Poniente6","Gustavo A. Madero","Iztacalco","Venustiano Carranza","Benito Juárez","Coyoacán","La Magdalena Contreras","Tlalpan","Iztapalapa","Milpa Alta","Tláhuac","Xochimilco","Álvaro Obregón","Azcapotzalco","Cuajimalpa de Morelos","Cuauhtémoc","Miguel Hidalgo"]],
	["Durango",["Durango","La Laguna1","La Laguna2"]],
	["Guanajuato",["León de los Aldama","Guanajuato"]],
	["Guerrero",["Acapulco de Juárez","Chilpancingo de los Bravo","Ixtapa-Zihuatanejo"]],
	["Hidalgo",["Pachuca de Soto"]],
	["Jalisco",["Guadalajara","Tonalá","Tlajomulco de Zúñiga","San Pedro Tlaquepaque","Zapopan","Puerto Vallarta"]],
	["México",["Toluca de Lerdo","Ecatepec de Morelos","Ciudad Nezahualcóyotl","Naucalpan de Juárez","Tlalnepantla de Baz","Atizapán de Zaragoza","Chimalhuacán","Cuautitlán Izcalli"]],
	["Michoacán",["Morelia","Uruapan","Lázaro Cárdenas"]],
	["Morelos",["Cuernavaca"]],
	["Nayarit",["Tepic"]],
	["Nuevo León",["Monterrey","San Pedro Garza García","Apodaca","Guadalupe","General Escobedo","San Nicolás de los Garza","Santa Catarina"]],
	["Oaxaca",["Oaxaca de Juárez"]],
	["Puebla",["Heroica Puebla de Zaragoza"]],
	["Querétaro",["Querétaro"]],
	["Quintana Roo",["Cancún"]],
	["San Luis Potosí",["San Luis Potosí"]],
	["Sinaloa",["Culiacán Rosales","Mazatlán","Los Mochis"]],
	["Sonora",["Hermosillo","Nogales"]],
	["Tabasco",["Villahermosa"]],
	["Tamaulipas",["Tampico","Reynosa","Nuevo Laredo"]],
	["Tlaxcala",["Tlaxcala de Xicohténcatl"]],
	["Veracruz",["Veracruz","Coatzacoalcos"]],
	["Yucatán",["Mérida"]],
	["Zacatecas",["Zacatecas","Fresnillo"]]
]

# ADD ENSU CITIES TO STATES
myCities.each{|city|
	myState = State.where(:name=>city[0]).last
	myState.update(:ensu_cities=>city[1])
}