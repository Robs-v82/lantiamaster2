#!/usr/bin/env ruby

# ============================================================
# Test Script: PASOS 1-9 con datos reales de la BD
# ============================================================

require_relative "../config/environment"
load "#{Rails.root}/scripts/ofac_pipeline_executor.rb"

puts "\n" + "=" * 100
puts "🚀 TEST: OFAC Pipeline PASOS 1-9 con Datos Reales"
puts "=" * 100

# Simulamos PASO 1: Usar candidato OFAC real
candidate = {
  firstname: "Carlos",
  lastname1: "Villela",
  lastname2: "Gomez Santelices",
  fullname: "Carlos Villela Gomez Santelices",
  ofac_raw: "VILLELA GOMEZ SANTELICES, Carlos",
  lastname_resolution_source: "database"
}

puts "\n✅ PASO 1 (Simulado): Candidato OFAC seleccionado"
puts "   #{candidate[:fullname]}"

# Recuperar Hit real de la BD
hit = Hit.find(6024)

unless hit.plain_text.present? && hit.plain_text.length >= 800
  puts "\n❌ Error: Hit no tiene plain_text válido"
  exit 1
end

puts "\n✅ PASO 2-4 (Simulados): Hit recuperado de la BD"
puts "   Legacy ID: #{hit.legacy_id}"
puts "   Date: #{hit.date}"
puts "   Plain text: #{hit.plain_text.length} caracteres"

# Simulamos PASO 5: Buscar cartel
sector = Sector.where(scian2: 98).last
organization = sector&.organizations&.where(active: true)&.first

puts "\n✅ PASO 5 (Simulado): Organización identificada"
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
puts "✅ FLUJO COMPLETADO - PASOS 1-9 EXITOSOS"
puts "=" * 100
puts "\n📊 Resumen Final:"
puts "   • Candidato: #{candidate[:fullname]}"
puts "   • Alias: #{paso7_result[:alias].inspect}"
puts "   • Rol: #{paso8_result[:role_name]}"
puts "   • Organización: #{organization&.name}"
puts "\n"
