if Organization.where(:name=>"Lantia Consultores").empty?
	Organization.create(:name=>"Lantia Consultores")
end

organizationKey = Organization.where(:name=>"Lantia Consultores").last.id

print "*****"
print organizationKey


people = [
	# [
	# 	{:mail=>"roberto@primeraraiz.com",:password=>"Paloma001",:password_confirmation=>"Paloma001"},
	# 	{:firstname=>"Roberto",:lastname1=>"Valladares",:lastname2=>"Piedras",:organization_id=>organizationKey}
	# ],
	# [
	# 	{:mail=>"eggmexico@gmail.com",:password=>"Test2020EG",:password_confirmation=>"Test2020EG"},
	# 	{:firstname=>"Eduardo",:lastname1=>"Guerrero",:lastname2=>"Gutiérrez",:organization_id=>organizationKey}	
	# ],
	# [
	# 	{:mail=>"eunisesrosillo@gmail.com",:password=>"Test2020ER",:password_confirmation=>"Test2020ER"},
	# 	{:firstname=>"Eunises",:lastname1=>"Rosillo",:lastname2=>"Ortiz",:organization_id=>organizationKey}
	# ]
	[{:mail=>"apulido@colmex.mx",:password=>"Txst2020ER",:password_confirmation=>"Txst2020ER",:query_counter=>0},
		{:firstname=>"Amalia",:lastname1=>"Pulido",:lastname2=>"Gómez",:organization_id=>organizationKey}],
	[{:mail=>"jorgezen@gmail.com",:password=>"Test2P20ER",:password_confirmation=>"Test2P20ER",:query_counter=>0},
		{:firstname=>"Jorge",:lastname1=>"Zenejas",:lastname2=>"Reyes",:organization_id=>organizationKey}],
	[{:mail=>"luis_osnaya@me.com",:password=>"QTest2020wR",:password_confirmation=>"QTest2020wR",:query_counter=>0},
		{:firstname=>"Luis",:lastname1=>"Osnaya",:organization_id=>organizationKey}],
	[{:mail=>"rodrigomoulinie@gmail.com",:password=>"Test7u2020PP",:password_confirmation=>"Test7u2020PP",:query_counter=>0},
		{:firstname=>"Rodrigo",:lastname1=>"Salido",:organization_id=>organizationKey}]
]

# users =[
# 	{:mail=>"roberto@primeraraiz.com",:password=>"Paloma001",:password_confirmation=>"Paloma001"},
# 	{:mail=>"eggmexico@gmail.com",:password=>"Test2020EG",:password_confirmation=>"Test2020EG"},
# 	{:mail=>"eunisesrosillo@gmail.com",:password=>"Test2020ER",:password_confirmation=>"Test2020ER"}
# ]

# members = [
# 	{:firstname0=>"Roberto",:lastname1=>"Valladares",:lastname2=>"Piedras",:organization_id=>organizationKey},
# 	{:firstname0=>"Eduardo",:lastname1=>"Guerrero",:lastname2=>"Gutiérrez",:organization_id=>organizationKey},
# 	{:firstname0=>"Eunises",:lastname1=>"Rosillo",:lastname2=>"Ortiz",:organization_id=>organizationKey}
# ]

people.each{|x|
	User.create(x[0])
	Member.create(x[1])
	memberKey = Member.last.id
	User.last.update(:member_id=>memberKey)
}
