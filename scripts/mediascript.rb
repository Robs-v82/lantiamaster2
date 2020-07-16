["Tijuana", "Uniradio Informa",510]
["Aguascalientes","El Heraldo de Aguascalientes",510]
["Tijuana","El Sol de Tijuana",510]



["Octavio Fabela", "Uniradio Informa"]
["Rubén Torres Cruz","El Heraldo de Aguascalientes"]
["Antonio Maya","El Sol de Tijuana"]


uniradio = Organization.where(:name=>"Uniradio Informa").last.id
heraldo = Organization.where(:name=>"El Heraldo de Aguascalientes").last.id
sol = Organization.where(:name=>"El Sol de Tijuana").last.id
universal = Organization.where(:name=>"El Universal").last.id

myMembers= [
	{:role_id=>2, :firstname=>"Octavio", :lastname1=>"Fabela", :organization_id=>uniradio},
	{:role_id=>2, :firstname=>"Rubén", :lastname1=>"Torres", :lastname2=>"Cruz", :organization_id=>heraldo},
	{:role_id=>2, :firstname=>"Antonio", :lastname1=>"Maya", :organization_id=>sol},
	{:role_id=>2, :firstname=>"Alejandro", :lastname1=>"Hope", :organization_id=>universal},
	{:role_id=>2, :firstname=>"Héctor", :lastname1=>"De Mauleón", :organization_id=>universal},
]


