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

end
