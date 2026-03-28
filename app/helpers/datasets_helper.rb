module DatasetsHelper

	def designated_ancestor_for(org)
		current = org&.parent
		while current.present?
		  return current if current.designation
		  current = current.parent
		end
		nil
	end

end
