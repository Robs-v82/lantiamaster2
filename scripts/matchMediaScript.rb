papers = Division.where(:scian3=>510).last.organizations

# CREATE  UNDEFINED MEMBER FOR EACH MEDIA ORGANIZATION
papers.each{|paper|
	if paper.members.where(:firstname=>"No registrado/Redacción").length == 0
		paper_id = paper.id
		Member.create(:firstname=>"No registrado/Redacción", :organization_id=>paper_id)
	end
}

# LINK SOURCES TO MEDIA ORGANIZATIONS BASED ON URL DOMAIN
mySources = Source.where(:member_id=>nil)

mySources.all.each {|source|
	papers.each {|paper|
		if paper.domain?
			myDomain = paper.domain
			if source.url.include?(myDomain)
				author_id = paper.members.where(:firstname=>"No registrado/Redacción").last.id
				source.update(:member_id=>author_id)
			end 
		end
	}
}