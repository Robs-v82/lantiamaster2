module CountiesHelper

	def zero_padded_full_code(myNumber)
		if myNumber.is_a? (String)
			myNumber = myNumber.to_i
		end
		myNumber = 100000+myNumber
		myNumber = myNumber.to_s
		myNumber = myNumber[1..-1]
		return myNumber
	end

	def bigCounties
		bigCounties = County.where("population > ?",100000)
		return bigCounties
	end

end
