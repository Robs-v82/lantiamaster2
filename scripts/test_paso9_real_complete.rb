#!/usr/bin/env ruby

# ============================================================
# Test Script: PASOS 1-9 Completo con Datos Reales de la BD
# ============================================================

# Cargar variables de entorno del archivo .env
env_file = File.expand_path("../.env", __dir__)
if File.exist?(env_file)
  File.readlines(env_file).each do |line|
    next if line.start_with?("#") || line.strip.empty?
    key, value = line.chomp.split("=", 2)
    ENV[key] = value if key && value
  end
end

require_relative "../config/environment"
load "#{Rails.root}/scripts/ofac_pipeline_executor.rb"

puts "\n" + "=" * 100
puts "🚀 TEST COMPLETO: OFAC Pipeline PASOS 1-9 con Datos Reales de la BD"
puts "=" * 100

# PASO 1: Usar candidato OFAC real
candidate = {
  firstname: "Carlos",
  lastname1: "Villela",
  lastname2: "Gomez Santelices",
  fullname: "Carlos Villela Gomez Santelices",
  ofac_raw: "VILLELA GOMEZ SANTELICES, Carlos",
  lastname_resolution_source: "database"
}

puts "\n✅ PASO 1: Candidato OFAC seleccionado"
puts "   #{candidate[:fullname]}"

# Buscar un Hit REAL que contenga el candidato
puts "\n🔍 Buscando Hit real que contenga al candidato..."
hit = Hit.where("plain_text ILIKE ?", "%#{candidate[:firstname]}%")
         .where("plain_text ILIKE ?", "%#{candidate[:lastname1]}%")
         .where("plain_text IS NOT NULL")
         .where("LENGTH(plain_text) >= 800")
         .where("date IS NOT NULL")
         .where("town_id IS NOT NULL")
         .order(created_at: :desc)
         .first

if hit.nil?
  puts "❌ No se encontró Hit con el candidato. Buscando alternativa..."
  # Buscar cualquier Hit válido y crear candidato ficticio con ese nombre
  hit = Hit.where("plain_text IS NOT NULL")
           .where("LENGTH(plain_text) >= 800")
           .where("date IS NOT NULL")
           .where("town_id IS NOT NULL")
           .order(created_at: :desc)
           .first

  if hit.nil?
    puts "❌ No hay Hits válidos en la BD"
    exit 1
  end

  # Extraer nombres del plain_text para crear candidato válido
  text = hit.plain_text.downcase
  puts "   Usando Hit genérico, buscando nombres en el texto..."

  # Fallback: usar un candidato que sabemos que funciona
  candidate = {
    firstname: "Guillermo",
    lastname1: "Valdés",
    lastname2: "Castellanos",
    fullname: "Guillermo Valdés Castellanos",
    ofac_raw: "VALDÉS CASTELLANOS, Guillermo",
    lastname_resolution_source: "database"
  }
  puts "   Candidato alternativo: #{candidate[:fullname]}"
else
  puts "   ✅ Hit encontrado con el candidato"
end

puts "\n✅ PASO 2-4 (Simulados): Hit con validación"
puts "   Hit ID: #{hit.id}"
puts "   Date: #{hit.date}"
puts "   Plain text: #{hit.plain_text.length} caracteres"

# Validar que el candidato aparece
validation_result = OfacPipeline::Step2.candidate_appears_in_text?(candidate, hit.plain_text)
puts "   ✅ Validación candidato en texto: #{validation_result}"

unless validation_result
  puts "\n❌ Candidato NO aparece en el plain_text. Abortando prueba."
  exit 1
end

# PASO 5: Buscar cartel
puts "\n✅ PASO 5 (Simulado): Organización identificada"
sector = Sector.where(scian2: 98).last
organization = sector&.organizations&.where(active: true)&.first
puts "   #{organization&.name || 'Desconocida'}"

# PASO 7: Extraer alias con Claude
puts "\n🤖 PASO 7: Extrayendo alias del candidato..."
paso7_result = OfacPipeline::Step7.execute!(candidate, hit)

# PASO 8: Determinar rol con Claude
puts "\n🤖 PASO 8: Determinando rol OFAC..."
paso8_result = OfacPipeline::Step8.execute!(candidate, hit, organization)

# PASO 9: Presentar confirmación
puts "\n"
OfacPipeline::Step9.present_for_confirmation(
  candidate,
  hit,
  organization,
  paso7_result[:alias],
  paso8_result[:role_name],
  paso8_result[:role_id]
)

puts "\n" + "=" * 100
puts "✅ PRUEBA COMPLETA - PASOS 1-9 EXITOSOS"
puts "=" * 100
puts "\n📊 Resumen Final:"
puts "   • Candidato: #{candidate[:fullname]}"
puts "   • Alias: #{paso7_result[:alias].inspect}"
puts "   • Rol: #{paso8_result[:role_name]}"
puts "   • Organización: #{organization&.name}"
puts "\n"
