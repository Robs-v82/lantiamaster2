r = Role.find_by_name("Regidor")
Member.where(:role=>r).each{|member|
	org = member.hits.last.town.county.organizations.first
	link = member.organization
	member.update(
		:organization=>org,
		:criminal_link=>link
		)
}