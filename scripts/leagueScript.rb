myLeagues = [
	{
		:name=>"Cártel",
		:description=>"Confederación de mafias y bandas con presencia regional o nacional. Los grupos que la conforman operan de forma independiente, pero coordinada —y sujetas a las decisiones estratégicas de un número limitado de individuos o liderazgos— con el objetivo de generar economías de escala y enfrentar exitosamente a rivales externos."

	},{
		:name=>"Mafia",
		:description=>"Organización regional con lazos familiares o de amistad, y conformada por bandas (brazos armados o pandillas). Son parte de cárteles, se subcontratan a estos, o trabajan de forma independiente."
	},{
		:name=>"Banda",
		:description=>"Grupo con presencia municipal o local. Suelen dedicarse a delitos menores o del fuero común. Recurren a otras organizaciones para abastecerse de insumos o se subcontratan a éstas para llevar a cavo delitos de alto impacto."
	},{
		:name=>"Brazo armado",
		:description=>"Grupo de profesionales de la violencia de cárteles o mafias. Puede ser parte de la estructura de la organización criminal o un cuerpos de reserva conformado por sicarios otorgados, o cedidos voluntariamente por las mafias o bandas que componen la organización."
	},{
		:name=>"Célula",
		:description=>"Mafia que funciona como franquicia de un cártel, que le concede el derecho para llevar a cabo ciertas actividades delictivas en una zona determinada como su representante."
	},{
		:name=>"Escisión",
		:description=>"Bifurcación, rompimiento o fragmento de otra organización criminal —en su mayoría pertenecían a antiguos cárteles—, que opera como mafia o banda independiente, o subordinada a otra organización."
	},{
		:name=>"Pandilla",
		:description=>"Grupo de individuos que adoptan una identidad colectiva para generar un sentido de pertenencia interna y una reputación externa por medio de actividades delictivas. Su presencia se limita a centros penitenciarios, barrios o calles en una población en específico."
	}
]
myLeagues.each{|league|
	relevant = League.where(:name=>league[:name])
	if relevant.empty?
		League.create(league)
	else
		relevant.update(league)
	end
}

	
