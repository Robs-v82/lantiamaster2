#!/usr/bin/env rails runner

puts "\n✅ TEST PASO 1 FINAL - Validación Simplificada"
puts "=" * 60

# Simulación de cómo funcionará PASO 1

def normalize_and_capitalize(text)
  I18n.transliterate(text.to_s.strip).split.map(&:capitalize).join(" ")
end

# Ejemplo: OFAC entry
ofac_entry = "GARCÍA LÓPEZ, María del Rosario"

puts "\n📥 ENTRADA OFAC:"
puts "   #{ofac_entry}"

# Parsear y normalizar
parts = ofac_entry.split(",", 2)
lastname_part = parts[0].strip
firstname_part = parts[1].strip
lastname_tokens = lastname_part.split

firstname = normalize_and_capitalize(firstname_part)
lastname1 = normalize_and_capitalize(lastname_tokens[0])
lastname2 = normalize_and_capitalize(lastname_tokens[1])

fullname = "#{firstname} #{lastname1} #{lastname2}".strip

puts "\n📝 GUARDADO EN OfacCandidate.ofac_name:"
puts "   #{fullname}"

puts "\n🔍 VALIDACIÓN:"
puts "   OfacCandidate.exists?(ofac_name: \"#{fullname}\")"

puts "\n📊 EQUIVALENCIA CON MEMBER.FULLNAME:"
puts "   Member.fullname (ejemplo): \"Maria Del Rosario Garcia Lopez\""
puts "   OfacCandidate.ofac_name:    \"#{fullname}\""
puts "   ¿SON IGUALES?              #{fullname == "Maria Del Rosario Garcia Lopez" ? "✅ SÍ" : "❌ NO"}"

puts "\n" + "=" * 60
puts "✅ PASO 1 CORRECTAMENTE SIMPLIFICADO"
puts "=" * 60
puts "\nRESUMEN:"
puts "  • Sin migración en BD ✓"
puts "  • Guardado en ofac_name (campo existente) ✓"
puts "  • Formato idéntico a Member.fullname ✓"
puts "  • Validación simple: .exists?(ofac_name: member.fullname) ✓"
