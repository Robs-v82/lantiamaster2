d = ["Cártel de Sinaloa", "Cártel Jalisco Nueva Generación", "Cárteles Unidos", "La Nueva Familia Michoacana", "Cártel del Noreste", "Cártel del Golfo"]
cartels = Organization.where(name: d)

cartels.each do |cartel|
  cartelArr = [cartel.name]
  myLeads = cartel.leads
  myStates = cartel.states.uniq

  myStates.each do |myState|
    myArr = []
    myState.leads.each{|l|
    	if myLeads.include? l
    		myArr.push(l)
    	end
    }
    stateCombo = { s: myState.name, c: myArr.count } # Corregido myState.name
    cartelArr.push(stateCombo)
  end

  puts cartelArr # `print` es menos legible para arrays grandes; mejor `puts`
end


