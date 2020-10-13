Detention.all.each{|i|
	i.detainees.destroy_all
	i.destroy
}