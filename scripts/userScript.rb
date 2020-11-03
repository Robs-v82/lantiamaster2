myMembers = [
	[{:firstname=>"Roberto",:lastname1=>"Valladares",:lastname2=>"Piedras"},{:mail=>"roberto@primeraraiz.com",:password=>"Paloma001",:password_confirmation=>"Paloma001"}],
	[{:firstname=>"Jorge",:lastname1=>"Zendejas",:lastname2=>"Reyes"},{:mail=>"jorgezen@gmail.com",:password=>"Zacatecas27",:password_confirmation=>"Zacatecas27"}],
	[{:firstname=>"Eduardo",:lastname1=>"Guerrero",:lastname2=>"Gutiérrez"},{:mail=>"eggmexico@gmail.com",:password=>"Guerrero08",:password_confirmation=>"Guerrero08"}],
	[{:firstname=>"Eunises",:lastname1=>"Rosillo",:lastname2=>"Ortiz"},{:mail=>"eunisesrosillo@gmail.com",:password=>"Tequisquiapan58",:password_confirmation=>"Tequisquiapan58"}],
	[{:firstname=>"Luis",:lastname1=>"Osnaya",:lastname2=>"Hoyos"},{:mail=>"luis_osnaya@me.com",:password=>"Tlalpan27",:password_confirmation=>"Tlalpan27"}],
	[{:firstname=>"Amalia",:lastname1=>"Pulido",:lastname2=>"Gómez"},{:mail=>"apulido@colmex.mx",:password=>"Puebla27",:password_confirmation=>"Puebla27"}]
]

myMembers.each{|member|
	Member.create(member[0])
	data = member[1]
	data[:member_id] = Member.last.id
	User.create(data)
}