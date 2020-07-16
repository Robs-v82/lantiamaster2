def booleanUpdate (myVariable, myNumber, myCode)
	target = Member.find(myNumber)
	target.update(:myVariable=>myCode)
	print taget
end

booleanUpdate(lastname1, 5, "Ros")