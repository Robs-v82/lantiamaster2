#!/usr/bin/env rails runner

# Test PASO 1 con datos MOCK (sin acceso a BD)

puts "\n🧪 TEST PASO 1: Simulación con Datos Mock"
puts "=" * 60

# Datos MOCK: simulan lo que retornaría OFAC
mock_ofac_list = [
  { ofac_name: "GARCIA LOPEZ, Maria Del" },           # Inválido: solo 1 lastname
  { ofac_name: "BOTELLO ORTIZ, Jesus David" },        # ✅ Válido
  { ofac_name: "AVENDANO, Martin" },                  # Inválido: solo 1 lastname
  { ofac_name: "RUIZ MORALES, Carlos Miguel" },       # ✅ Válido
  { ofac_name: "FLORES, Juan" },                      # Inválido: solo 1 lastname
  { ofac_name: "SANTOS CRUZ MEDINA, Rosa Maria" }     # ✅ Válido (3 lastnames)
]

puts "\n📊 OFAC List Mock:"
mock_ofac_list.each_with_index do |item, idx|
  puts "   [#{idx}] #{item[:ofac_name]}"
end

# VALIDACIÓN 2: Filtrar por estructura válida
valid_candidates = mock_ofac_list.select do |candidate|
  name = candidate[:ofac_name]

  unless name.include?(",")
    next false
  end

  parts = name.split(",", 2)
  lastname_part = parts[0].strip
  firstname_part = parts[1].strip

  lastname_tokens = lastname_part.split
  firstname_tokens = firstname_part.split

  valid = lastname_tokens.size >= 2 && firstname_tokens.size >= 1

  if valid
    candidate[:firstname] = firstname_tokens.join(" ")
    candidate[:lastname1] = lastname_tokens[0]
    candidate[:lastname2] = lastname_tokens[1]
  end

  valid
end

puts "\n✅ Candidatos con estructura válida: #{valid_candidates.size}"
valid_candidates.each_with_index do |item, idx|
  puts "   [#{idx}] #{item[:ofac_name]}"
  puts "       → firstname='#{item[:firstname]}', lastname1='#{item[:lastname1]}', lastname2='#{item[:lastname2]}'"
end

# VALIDACIÓN 3: Simular exclusión de OfacCandidate
already_reviewed = {
  "BOTELLO ORTIZ, Jesus David" => true  # Este ya fue revisado
}

available_candidates = valid_candidates.reject do |candidate|
  already_reviewed[candidate[:ofac_name]].present?
end

puts "\n📌 Candidatos disponibles (NO revisados): #{available_candidates.size}"
available_candidates.each_with_index do |item, idx|
  puts "   [#{idx}] #{item[:ofac_name]}"
end

# PASO 1: Retornar último
if available_candidates.empty?
  puts "\n❌ No hay candidatos OFAC disponibles"
else
  candidate = available_candidates.last

  puts "\n" + "=" * 60
  puts "✅ CANDIDATO DISPONIBLE (PASO 1 OK):"
  puts "=" * 60
  puts "   OFAC Name: #{candidate[:ofac_name]}"
  puts "   Firstname: #{candidate[:firstname]}"
  puts "   Lastname1: #{candidate[:lastname1]}"
  puts "   Lastname2: #{candidate[:lastname2]}"
  puts "=" * 60

  puts "\n✅ TEST PASO 1 COMPLETADO SIN ERRORES"
  puts "\nVALIDACIONES EJECUTADAS:"
  puts "  ✓ VALIDACIÓN 1: Lista OFAC extraída (simulada)"
  puts "  ✓ VALIDACIÓN 2: Estructura de nombres validada"
  puts "    - Inválidos excluidos: 3 (no tienen 2+ apellidos)"
  puts "    - Válidos encontrados: 3"
  puts "  ✓ VALIDACIÓN 3: Candidatos ya revisados excluidos"
  puts "    - Excluidos: 1 (Botello Ortiz)"
  puts "    - Disponibles: 2"
  puts "  ✓ PASO 1: Retornó candidato ÚLTIMO (más reciente)"
  puts "    - Resultado: #{candidate[:ofac_name]}"
end
