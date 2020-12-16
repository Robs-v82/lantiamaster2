module VictimsHelper

	def gender_keys
		keys = [
			{:name=>"Femenino", :color=>"#EF4E50"},
			{:name=>"Masculino", :color=>"#80CBCB"},
			{:name=>"Sin definir", :color=>'#E0E0E0'}
		]
		return keys	
	end

	def age_keys
		keys = [
			{:name=>"50 +", :range=>[50,100000]},
			{:name=>"40s", :range=>[40,49]},
			{:name=>"30s", :range=>[30,39]},
			{:name=>"20s", :range=>[20,29]},
			{:name=>"< 20", :range=>[0,19]}
		]
	end

	def police_keys
		keys = [
			{:name=>"SEDENA", :categories=>["Militar SEDENA"]},
			# {:name=>"SEMAR", :categories=>["Militar SEMAR"]},
			{:name=>"PF/GN", :categories=>["Guardia Nacional", "Policía Federal"]},
			{:name=>"Policía Estatal", :categories=>["Policía Estatal (caminos)", "Policía Estatal (investigación)", "Policía Estatal (procesal)", "Policía Estatal (reacción)", "Policía Estatal (auxiliar)", "Policía Estatal (custodio penitenciario)", "Policía Estatal (bancaria)", "Policía Estatal (no especificado)"]},
			{:name=>"Policía Municipal", :categories=>["Policía Municipal (preventivo)","Policía Municipal (tránsito o vial)","Policía Municipal (comunitario)","Policía Municipal (no especificado)"]},
			{:name=>"Policía (no especificado)", :categories=>["Policía No Especificado u otro"]},
			# {:name=>"FGR/Fiscalía Estatal", :categories=>[]}
		]
		return keys
	end

end
