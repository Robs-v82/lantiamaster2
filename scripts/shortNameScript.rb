County.where(:name=>"San Miguel de Allende").last.update(:shortname=>"San Miguel de Allende")
County.where(:full_code=>"23005").last.update(:shortname=>"Cancún (Benito Juárez)")
County.where(:full_code=>"23008").last.update(:shortname=>"Playa del Carmen (Solidaridad)")
County.where(:full_code=>"12038").last.update(:shortname=>"Zihuatanejo")
County.where(:full_code=>"07078").last.update(:shortname=>"San Cristóbal de las Casas")
County.where(:full_code=>"15122").last.update(:shortname=>"Valle de Chalco")
County.where(:full_code=>"30102").last.update(:shortname=>"Martínez de la Torre")
County.where(:full_code=>"15070").last.update(:shortname=>"Los Reyes La Paz")
County.where(:full_code=>"20184").last.update(:shortname=>"Tuxtepec")
County.where(:full_code=>"13051").last.update(:shortname=>"Mineral de la Reforma")
County.where(:full_code=>"11014").last.update(:shortname=>"Dolores Hidalgo")
County.where(:full_code=>"06010").last.update(:shortname=>"Villa de Álvarez")
County.where(:full_code=>"15110").last.update(:shortname=>"Valle de Bravo")
County.where(:full_code=>"14053").last.update(:shortname=>"Lagos de Moreno")
County.where(:full_code=>"14073").last.update(:shortname=>"San Juan de los Lagos")
County.where(:full_code=>"18020").last.update(:shortname=>"Bahía de Banderas")
County.where(:full_code=>"17017").last.update(:shortname=>"Puente de Ixtla")
["Villa","Valle","Chiapa"].each{|common|
	County.where(:shortname=>common).each{|county|
		county.update(:shortname=>county.name)
	}
}