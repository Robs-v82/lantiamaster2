#!/usr/bin/env rails runner

puts "\n🔍 TEST: Validación de OfacCandidate"
puts "=" * 60

# Comando 1: Verificar si "LEAL JIMENEZ, Joaquin" está en OfacCandidate
ofac_name = "LEAL JIMENEZ, Joaquin"

puts "\n1️⃣ COMANDO RUBY (Búsqueda Directa):"
puts "   OfacCandidate.find_by(ofac_name: \"#{ofac_name}\")"

result = OfacCandidate.find_by(ofac_name: ofac_name)

puts "\n   Resultado: #{result.inspect}"

if result.nil?
  puts "   ✅ NO está en OfacCandidate (disponible para procesar)"
else
  puts "   ❌ YA está en OfacCandidate (ya fue revisado)"
  puts "      Status: #{result.status}"
  puts "      Created at: #{result.created_at}"
end

# Comando 2: Verificar usando exists?
puts "\n2️⃣ COMANDO RUBY (Verificación de Existencia):"
puts "   OfacCandidate.exists?(ofac_name: \"#{ofac_name}\")"

exists = OfacCandidate.exists?(ofac_name: ofac_name)

puts "\n   Resultado: #{exists}"
puts "   → #{exists ? '❌ YA existe' : '✅ NO existe'}"

# Comando 3: Mostrar total de registros en OfacCandidate
puts "\n3️⃣ COMANDO RUBY (Conteo Total):"
puts "   OfacCandidate.count"

count = OfacCandidate.count

puts "\n   Resultado: #{count}"
puts "   → Total de candidatos ya revisados: #{count}"

# Comando 4: Si hubiera, mostrar qué está en OfacCandidate
if count > 0
  puts "\n4️⃣ Registros en OfacCandidate (primeros 5):"
  OfacCandidate.limit(5).each do |candidate|
    puts "   - #{candidate.ofac_name} (status: #{candidate.status})"
  end
else
  puts "\n4️⃣ OfacCandidate está VACÍA"
end

# Resumen
puts "\n" + "=" * 60
puts "✅ TEST VALIDACIÓN COMPLETADO"
puts "=" * 60
puts "\nRESUMEN:"
puts "  • Búsqueda exacta por ofac_name: FUNCIONA"
puts "  • Búsqueda con exists?: FUNCIONA (más eficiente)"
puts "  • Total en OfacCandidate: #{count}"
puts "  • Ejemplo 'LEAL JIMENEZ, Joaquin': #{exists ? 'REVISADO' : 'DISPONIBLE'}"
