#!/usr/bin/env ruby

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
puts "🚀 PIPELINE OFAC COMPLETO: PASOS 1-9"
puts "=" * 100

begin
  candidate = OfacPipeline::Step1.execute!

  if candidate.nil?
    puts "\n❌ No hay candidatos disponibles"
    exit 1
  end

  step2_result = OfacPipeline::Step2.execute!(candidate)

  if step2_result.nil?
    puts "\n❌ No se encontró Hit válido en PASOS 1-5"
    exit 1
  end

  # Obtener Hit más reciente (Step2 acaba de procesar uno)
  hit = Hit.order(created_at: :desc).first

  if hit.nil?
    puts "\n❌ No hay Hits en la BD"
    exit 1
  end

  organization = hit.organization

  puts "\n🤖 PASO 7: Extrayendo alias con Claude..."
  puts "=" * 60
  paso7_result = OfacPipeline::Step7.execute!(candidate, hit)

  puts "\n🤖 PASO 8: Determinando rol con Claude..."
  puts "=" * 60
  paso8_result = OfacPipeline::Step8.execute!(candidate, hit, organization)

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
  puts "✅ PIPELINE COMPLETO - PASOS 1-9 EXITOSOS"
  puts "=" * 100

rescue => e
  puts "\n❌ ERROR EN PIPELINE:"
  puts "   #{e.class}: #{e.message}"
  puts e.backtrace.first(10)
  exit 1
end
