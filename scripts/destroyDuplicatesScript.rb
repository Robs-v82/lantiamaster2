killings = Month.where(:name=>"2025_02").last.killings
killings.each{|k|
	legacy = k.legacy_id
	if killings.where(:legacy_id=>legacy).length > 1
		k.victims.destroy_all
		k.destroy
	end
}
print "Ready!"