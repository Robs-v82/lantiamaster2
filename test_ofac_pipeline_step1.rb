#!/usr/bin/env rails runner

# Test PASO 1

load Rails.root.join("scripts/ofac_pipeline_step1.rb").to_s

puts "\n🧪 TEST PASO 1: Identificar Candidato OFAC Disponible"
puts "Timestamp: #{Time.now}\n"

result = OfacPipeline::Step1.execute!

if result.nil?
  puts "\n📊 TEST RESULTADO: PASO 1 retornó nil (esperado si no hay candidatos)"
else
  puts "\n📊 TEST RESULTADO: PASO 1 exitoso"
  puts "\nDatos retornados:"
  puts "  - ofac_name: #{result[:ofac_name].inspect}"
  puts "  - firstname: #{result[:firstname].inspect}"
  puts "  - lastname1: #{result[:lastname1].inspect}"
  puts "  - lastname2: #{result[:lastname2].inspect}"

  # Validar estructura
  unless result[:ofac_name].include?(",")
    puts "\n❌ ERROR: ofac_name no tiene coma separadora"
    exit 1
  end

  unless result[:firstname] && result[:firstname].length > 0
    puts "\n❌ ERROR: firstname está vacío"
    exit 1
  end

  unless result[:lastname1] && result[:lastname2]
    puts "\n❌ ERROR: falta lastname1 o lastname2"
    exit 1
  end

  puts "\n✅ TEST PASO 1: COMPLETADO SIN ERRORES"
end
