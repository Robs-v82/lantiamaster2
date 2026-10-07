#!/usr/bin/env ruby

# ============================================================
# OFAC Pipeline Principal: PASOS 1-8 Independientes
# ============================================================

# Cargar variables de entorno
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
puts "🚀 OFAC PIPELINE PRINCIPAL: PASOS 1-8"
puts "=" * 100

SCRIPT_START_TIME = Time.now

begin
  # ============================================================
  # PASO 1: Identificar Candidato OFAC
  # ============================================================
  puts "\n📋 PASO 1: Identificar Candidato OFAC Disponible"
  puts "=" * 100
  candidate = OfacPipeline::Step1.execute!

  if candidate.nil?
    puts "\n❌ No hay candidatos OFAC disponibles"
    exit 1
  end

  # ============================================================
  # PASO 2: Buscar Hit con WebSearch
  # ============================================================
  puts "\n📡 PASO 2: Buscar Evidencia de Cartel"
  puts "=" * 100
  hit = OfacPipeline::Step2.execute!(candidate)

  if hit.nil?
    puts "\n❌ No se encontró Hit válido en PASO 2"
    exit 1
  end

  # ============================================================
  # PASO 3: Extraer Fecha con Claude
  # ============================================================
  puts "\n📅 PASO 3: Extraer Fecha con Claude"
  puts "=" * 100
  paso3_result = OfacPipeline::Step3.execute!(hit)
  hit.reload  # Recargar Hit con los datos actualizados de PASO 3

  if paso3_result.nil?
    puts "⚠️  PASO 3 completado con fallback"
  end

  # ============================================================
  # PASO 4: Extraer Ubicación con Claude
  # ============================================================
  puts "\n📍 PASO 4: Extraer Ubicación con Claude"
  puts "=" * 100
  paso4_result = OfacPipeline::Step4.execute!(hit)
  hit.reload  # Recargar Hit con los datos actualizados de PASO 4

  if paso4_result.nil?
    puts "⚠️  PASO 4 completado con fallback"
  end

  # ============================================================
  # PASO 5: Validar Cartel en Catálogo
  # ============================================================
  puts "\n🏢 PASO 5: Validar Vinculación con Cartel en Catálogo"
  puts "=" * 100
  paso5_result = OfacPipeline::Step5.execute!(hit)

  # ============================================================
  # PASO 6: Validación Final de Requisitos Críticos
  # ============================================================
  puts "\n" + "=" * 100
  organization_id = paso5_result && paso5_result[:found] ? paso5_result[:organization_id] : nil
  organization = paso5_result && paso5_result[:found] ? paso5_result[:organization] : nil

  paso6_result = OfacPipeline::Step6.validate_and_retry(
    candidate,
    hit,
    organization_id,
    was_existing_hit: false
  )

  if !paso6_result[:success]
    puts "\n❌ PASO 6 FALLÓ - FLUJO TERMINADO"
    puts "Causa: #{paso6_result[:primary_cause]}"
    exit 1
  end

  # ============================================================
  # PASO 7: Extraer Alias con Claude
  # ============================================================
  puts "\n🎭 PASO 7: Extraer Alias del Candidato"
  puts "=" * 100
  OfacPipeline.start_timer("PASO 7 (Total)")
  paso7_result = OfacPipeline::Step7.execute!(candidate, hit)
  OfacPipeline.end_timer("PASO 7 (Total)")

  if paso7_result.nil? || !paso7_result[:success]
    puts "⚠️  PASO 7 completado con fallback"
    paso7_result = { success: true, alias: [] }
  end

  # ============================================================
  # PASO 8: Determinar Rol OFAC
  # ============================================================
  puts "\n👤 PASO 8: Determinar Rol OFAC"
  puts "=" * 100
  OfacPipeline.start_timer("PASO 8 (Total)")
  paso8_result = OfacPipeline::Step8.execute!(candidate, hit, organization)
  OfacPipeline.end_timer("PASO 8 (Total)")

  if paso8_result.nil? || !paso8_result[:success]
    puts "⚠️  PASO 8 completado con fallback"
    paso8_result = { success: true, role_name: "Sin definir", role_id: nil, confidence: 0 }
  end

  # ============================================================
  # PASO 8.5: Estimar Género
  # ============================================================
  puts "\n👤 PASO 8.5: Estimar Género"
  puts "=" * 100
  OfacPipeline.start_timer("PASO 8.5 (Total)")
  paso8_5_result = OfacPipeline::StepGender.execute!(candidate, hit)
  OfacPipeline.end_timer("PASO 8.5 (Total)")

  if paso8_5_result[:success]
    puts "✓ Género: #{paso8_5_result[:gender]} (#{paso8_5_result[:source]}, confianza: #{paso8_5_result[:confidence]}%)"
  else
    puts "⚠️  No se pudo estimar género"
    paso8_5_result = { success: true, gender: "DESCONOCIDO", source: "fallback", confidence: 0 }
  end

  # ============================================================
  # PASO 9: Presentar Tablas de Confirmación
  # ============================================================
  puts "\n🎯 PASO 9: Presentar Tablas de Confirmación"
  puts "=" * 100
  OfacPipeline.start_timer("PASO 9 (Total)")

  OfacPipeline::Step9.present_for_confirmation(
    candidate,
    hit,
    organization,
    paso7_result && paso7_result[:alias] ? paso7_result[:alias] : [],
    paso8_result && paso8_result[:role_name] ? paso8_result[:role_name] : "Sin definir",
    paso8_result && paso8_result[:role_id] ? paso8_result[:role_id] : nil
  )

  OfacPipeline.end_timer("PASO 9 (Total)")

  puts "\n" + "=" * 100
  puts "✅ PASOS 1-9 COMPLETADOS EXITOSAMENTE"
  puts "=" * 100

  # ============================================================
  # RESUMEN DE EJECUCIÓN
  # ============================================================
  puts "\n" + "=" * 100
  puts "📋 RESUMEN DE EJECUCIÓN"
  puts "=" * 100

  puts "\n✅ RESULTADO EXITOSO:"
  puts "   Candidato: #{candidate[:fullname]}"
  puts "   Hit ID: #{hit.id}"
  puts "   Título: #{hit.title[0, 80]}..."
  puts "   Fecha: #{hit.date}"
  puts "   Ubicación: #{hit.town&.county&.name}, #{hit.town&.county&.state&.name}"
  if paso5_result && paso5_result[:found]
    puts "   Organización: #{paso5_result[:organization].name} (Confianza: #{paso5_result[:confidence]}%)"
  else
    puts "   Organización: No identificada"
  end

  if paso7_result && paso7_result[:alias].any?
    puts "   Alias: #{paso7_result[:alias].join(', ')}"
  else
    puts "   Alias: No identificados"
  end

  if paso8_result && paso8_result[:role_name]
    puts "   Rol: #{paso8_result[:role_name]} (Confianza: #{paso8_result[:confidence]}%)"
  else
    puts "   Rol: No identificado"
  end

  # ============================================================
  # TIEMPOS DE EJECUCIÓN
  # ============================================================
  puts "\n" + "=" * 100
  puts "⏱️  RESUMEN DE TIEMPOS DE EJECUCIÓN"
  puts "=" * 100

  script_total_time = Time.now - SCRIPT_START_TIME
  puts "\n📊 Tiempo total del script: #{script_total_time.round(2)}s"

  puts "\n🔍 Detalles por PASO:"
  puts "   PASO 1 (Total): #{(OfacPipeline.get_all_timings['PASO 1 (Total)'] || 0).round(2)}s"
  puts "   PASO 2 (Total): #{(OfacPipeline.get_all_timings['PASO 2 (Total)'] || 0).round(2)}s"
  puts "   PASO 3 (Total): #{(OfacPipeline.get_all_timings['PASO 3 (Total)'] || 0).round(2)}s"
  puts "   PASO 4 (Total): #{(OfacPipeline.get_all_timings['PASO 4 (Total)'] || 0).round(2)}s"
  puts "   PASO 5 (Total): #{(OfacPipeline.get_all_timings['PASO 5 (Total)'] || 0).round(2)}s"
  puts "   PASO 7 (Total): #{(OfacPipeline.get_all_timings['PASO 7 (Total)'] || 0).round(2)}s"
  puts "   PASO 8 (Total): #{(OfacPipeline.get_all_timings['PASO 8 (Total)'] || 0).round(2)}s"
  puts "   PASO 9 (Total): #{(OfacPipeline.get_all_timings['PASO 9 (Total)'] || 0).round(2)}s"

  puts "\n📍 Detalles de Sub-procesos:"
  OfacPipeline.get_all_timings.each do |label, time|
    next if label.include?("(Total)")
    puts "   #{label}: #{time.round(2)}s"
  end

  puts "\n" + "=" * 100 + "\n"

rescue => e
  puts "\n❌ ERROR:"
  puts "   #{e.class}: #{e.message}"
  puts e.backtrace.first(10)
  exit 1
end
