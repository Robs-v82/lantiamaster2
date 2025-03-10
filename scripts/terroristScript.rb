d = ["Cártel de Sinaloa", "Cártel Jalisco Nueva Generación", "Cárteles Unidos", "La Nueva Familia Michoacana", "Cártel del Noreste", "Cártel del Golfo"]
cartels = Organization.where(name: d)

cartels.each do |cartel|
  cartelArr = [cartel.name]
  myLeads = cartel.leads
  myStates = cartel.states.uniq

  myStates.each do |myState|
    myArr = myLeads.select { |l| l.event.state == myState } # Filtramos los leads de forma más eficiente

    stateCombo = { s: myState.name, c: myArr.count } # Corregido myState.name
    cartelArr.push(stateCombo)
  end

  puts cartelArr # `print` es menos legible para arrays grandes; mejor `puts`
end


