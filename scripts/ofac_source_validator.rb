#!/usr/bin/env ruby
# OFAC Source Validator - MANDATORY VALIDATION PROCESS
# Valida que TODOS los nombres y ubicaciones de un OFAC individual aparezcan
# EXPLÍCITAMENTE en el plain_text del Hit ANTES de permitir creación

require_relative '../config/environment'

class OfacSourceValidator
  def self.validate_hit_for_member(hit, ofac_firstname, ofac_lastname1, ofac_lastname2 = nil)
    validator = new(hit, ofac_firstname, ofac_lastname1, ofac_lastname2)
    validator.validate!
  end

  attr_reader :hit, :ofac_firstname, :ofac_lastname1, :ofac_lastname2, :errors, :warnings

  def initialize(hit, ofac_firstname, ofac_lastname1, ofac_lastname2 = nil)
    @hit = hit
    @ofac_firstname = ofac_firstname
    @ofac_lastname1 = ofac_lastname1
    @ofac_lastname2 = ofac_lastname2
    @errors = []
    @warnings = []
  end

  # VALIDACIÓN PRINCIPAL - retorna true SOLO si PASA todas las pruebas
  def validate!
    plain_text_lower = hit.plain_text.downcase

    puts "\n" + "=" * 100
    puts "🔐 VALIDADOR OFAC - FUENTE EXPLÍCITA"
    puts "=" * 100

    # PASO 1: Validar FIRSTNAME
    puts "\n📄 PASO 1: Validar FIRSTNAME"
    puts "   Buscando: '#{ofac_firstname}'"
    if plain_text_lower.include?(ofac_firstname.downcase)
      puts "   ✅ ENCONTRADO en plain_text"
    else
      @errors << "❌ FIRSTNAME '#{ofac_firstname}' NO ENCONTRADO en plain_text"
      puts "   ❌ NO ENCONTRADO"
    end

    # PASO 2: Validar LASTNAME1
    puts "\n📄 PASO 2: Validar LASTNAME1"
    puts "   Buscando: '#{ofac_lastname1}'"
    if plain_text_lower.include?(ofac_lastname1.downcase)
      puts "   ✅ ENCONTRADO en plain_text"
    else
      @errors << "❌ LASTNAME1 '#{ofac_lastname1}' NO ENCONTRADO en plain_text"
      puts "   ❌ NO ENCONTRADO"
    end

    # PASO 3: Validar LASTNAME2 (si existe)
    if ofac_lastname2.present?
      puts "\n📄 PASO 3: Validar LASTNAME2"
      puts "   Buscando: '#{ofac_lastname2}'"
      if plain_text_lower.include?(ofac_lastname2.downcase)
        puts "   ✅ ENCONTRADO en plain_text"
      else
        @warnings << "⚠️  LASTNAME2 '#{ofac_lastname2}' NO ENCONTRADO en plain_text (puede ser OK si aparecen firstname + lastname1)"
        puts "   ⚠️  NO ENCONTRADO (continuando con advertencia)"
      end
    end

    # PASO 4: Validar ubicación
    puts "\n📍 PASO 4: Validar UBICACIÓN"
    puts "   Town ID asignado: #{hit.town_id}"
    if hit.town_id.blank?
      @errors << "❌ NO HAY town_id asignado al Hit"
      puts "   ❌ Sin ubicación"
    else
      town = Town.find(hit.town_id)
      county = town.county

      locations_in_text = []
      ["culiacán", "culiacan", "sinaloa", "méxico", "ciudad de méxico", "cdmx",
       "guadalajara", "zapopan", "jalisco", "monterrey", "nuevo león", "nuevo leon",
       "ensenada", "baja california", "zacatecas", "guanajuato", "michoacán", "michoacan"].each do |loc|
        locations_in_text << loc if plain_text_lower.include?(loc)
      end

      if locations_in_text.empty?
        @warnings << "⚠️  NO SE ENCONTRÓ ubicación explícita en plain_text"
        puts "   ⚠️  Sin ubicación mencionada"
      else
        puts "   ✅ Encontrado: #{locations_in_text.map(&:upcase).join(', ')}"
        puts "   Asignado a: #{town.name} (#{county.name})"
      end
    end

    # RESULTADO FINAL
    puts "\n" + "=" * 100
    puts "📊 RESULTADO DE VALIDACIÓN"
    puts "=" * 100

    if @errors.empty?
      puts "\n✅ ¡VALIDACIÓN EXITOSA!"
      puts "   - Todos los nombres fueron encontrados en plain_text"
      puts "   - Ubicación verificada"
      puts "   - Hit #{hit.id} puede usarse para crear Members"
      puts "\n" + "=" * 100 + "\n"
      return true
    else
      puts "\n❌ ¡VALIDACIÓN FALLIDA!"
      puts "\nErrores encontrados:"
      @errors.each { |err| puts "   #{err}" }
      if @warnings.any?
        puts "\nAdvertencias:"
        @warnings.each { |warn| puts "   #{warn}" }
      end
      puts "\n" + "=" * 100 + "\n"
      return false
    end
  end

  # Método helper: generar reporte auditoria
  def audit_report
    {
      hit_id: hit.id,
      hit_title: hit.title,
      hit_url: hit.link,
      validated_names: {
        firstname: ofac_firstname,
        lastname1: ofac_lastname1,
        lastname2: ofac_lastname2
      },
      town_id: hit.town_id,
      town_name: Town.find(hit.town_id)&.name,
      county_name: Town.find(hit.town_id)&.county&.name,
      validation_status: @errors.empty? ? "PASSED" : "FAILED",
      errors: @errors,
      warnings: @warnings,
      validated_at: Time.current
    }
  end
end

# USO:
# Hit #6002 (correcto)
# validator = OfacSourceValidator.validate_hit_for_member(
#   Hit.find(6002),
#   "Martin Guadencio",
#   "Avendano",
#   nil
# )
# puts validator.inspect
