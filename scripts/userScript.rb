users=[
	{:mail=>"roberto@primeraraiz.com",:password=>"Paloma001",:password_confirmation=>"Paloma001",:mobile_phone=>5544545312}
]

users.each{|x|
	User.create(x)
}
