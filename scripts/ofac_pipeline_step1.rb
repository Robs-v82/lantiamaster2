#!/usr/bin/env ruby

require "set"
require "csv"
require "open-uri"
require "fileutils"

# ============================================================
# OFAC Member Pipeline - PASO 1
# Identificar Candidato OFAC Disponible (con Normalización)
# ============================================================

module OfacPipeline
end

class OfacPipeline::UpdateError < StandardError; end

class OfacPipeline::Step1
  def self.execute!
    begin
      puts "\n🔍 PASO 1: Identificar Candidato OFAC Disponible"
      puts "=" * 60

      # 1. Obtener lista OFAC sin match
      ofac_list = extract_ofac_no_match_list
      puts "📊 Total OFAC sin match: #{ofac_list.size}"

      # 2. Filtrar candidatos válidos (estructura: firstname + lastname1 + lastname2)
      valid_candidates = filter_valid_candidates(ofac_list)
      puts "✅ Candidatos con estructura válida: #{valid_candidates.size}"

      # 3. Excluir ya revisados en OfacCandidate
      available_candidates = filter_not_reviewed(valid_candidates)
      puts "📌 Candidatos NO revisados aún: #{available_candidates.size}"

      # 4. Retornar último (más reciente según orden OFAC)
      if available_candidates.empty?
        puts "\n❌ No hay candidatos OFAC disponibles"
        puts "   (Todos fueron revisados o no cumplen estructura válida)"
        return nil
      end

      candidate = available_candidates.last  # último = más reciente

      puts "\n" + "=" * 60
      puts "✅ CANDIDATO DISPONIBLE (PASO 1 OK):"
      puts "=" * 60
      puts "   OFAC Original:         #{candidate[:ofac_raw]}"
      puts "   Fullname (para BD):    #{candidate[:fullname]}"
      puts "   Components:"
      puts "     - Firstname: #{candidate[:firstname]}"
      puts "     - Lastname1: #{candidate[:lastname1]}"
      puts "     - Lastname2: #{candidate[:lastname2]}"
      puts "=" * 60

      return candidate

    rescue OfacPipeline::UpdateError => e
      puts "\n❌ ERROR EN PASO 1:"
      puts "   #{e.message}"
      exit 1
    rescue => e
      puts "\n❌ ERROR INESPERADO EN PASO 1:"
      puts "   #{e.class}: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    end
  end

  private

  # ============================================================
  # VALIDACIÓN 1: Obtener lista "SIN MATCH" de OFAC
  # ============================================================
  def self.extract_ofac_no_match_list
    puts "\n📥 Extrayendo lista OFAC sin match..."

    base_url = "https://www.treasury.gov/ofac/downloads"
    sdn_url = "#{base_url}/sdn.csv"
    add_url = "#{base_url}/add.csv"

    data_dir = Rails.root.join("tmp", "ofac_data")
    FileUtils.mkdir_p(data_dir)

    sdn_path = data_dir.join("sdn.csv")
    add_path = data_dir.join("add.csv")

    # Descargar SDN
    puts "   Descargando sdn.csv..."
    begin
      headers = { "User-Agent" => "Mozilla/5.0 (Ruby OFAC script)" }
      URI.open(sdn_url, headers.merge(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)) do |remote|
        File.binwrite(sdn_path, remote.read)
      end
    rescue => e
      raise OfacPipeline::UpdateError, "No se pudo descargar sdn.csv: #{e.message}"
    end

    # Descargar ADD
    puts "   Descargando add.csv..."
    begin
      headers = { "User-Agent" => "Mozilla/5.0 (Ruby OFAC script)" }
      URI.open(add_url, headers.merge(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)) do |remote|
        File.binwrite(add_path, remote.read)
      end
    rescue => e
      raise OfacPipeline::UpdateError, "No se pudo descargar add.csv: #{e.message}"
    end

    # 1. Identificar INDIVIDUALES en SDN
    individuals = {}
    CSV.foreach(sdn_path, headers: false, encoding: "bom|utf-8") do |row|
      next if row.nil?
      ent_num = row[0].to_s.strip
      name = row[1].to_s.strip
      type = row[2].to_s.strip.upcase
      next unless type == "INDIVIDUAL"
      individuals[ent_num] = { name: name }
    end

    puts "   📄 Individuales encontrados: #{individuals.size}"

    # 2. Identificar MÉXICO en ADD
    mexico_ent_nums = Set.new
    CSV.foreach(add_path, headers: false, encoding: "bom|utf-8") do |row|
      next if row.nil? || row.length < 5
      ent_num = row[0].to_s.strip
      country = row[4].to_s.strip
      next unless country == "Mexico" && individuals.key?(ent_num)
      mexico_ent_nums.add(ent_num)
    end

    puts "   🗺️  Individuales México: #{mexico_ent_nums.size}"

    # 3. Filtrar: solo México sin match en BD
    matched_ent_nums = Set.new
    Member.where(ofac_designation: true).where.not(ofac_ent_num: [nil, ""]).find_each do |m|
      matched_ent_nums.add(m.ofac_ent_num.to_s)
    end

    puts "   ✓ Members con match: #{matched_ent_nums.size}"

    no_match_list = mexico_ent_nums.reject { |ent_num| matched_ent_nums.include?(ent_num) }

    # 4. Retornar lista completa
    no_match_list.map do |ent_num|
      { ofac_name: individuals[ent_num][:name] }
    end
  end

  # ============================================================
  # VALIDACIÓN 2: Filtrar por estructura válida + Normalizar nombres
  # ============================================================
  def self.filter_valid_candidates(ofac_list)
    ofac_list.select do |candidate|
      name = candidate[:ofac_name]

      # Parsear: "LASTNAME, Firstname..."
      unless name.include?(",")
        next false
      end

      parts = name.split(",", 2)
      lastname_part = parts[0].strip
      firstname_part = parts[1].strip

      # Tokenizar
      lastname_tokens = lastname_part.split
      firstname_tokens = firstname_part.split

      # Validar estructura: lastname 2+, firstname 1+
      valid = lastname_tokens.size >= 2 && firstname_tokens.size >= 1

      if valid
        # NORMALIZACIÓN: transliterar acentos, capitalizar
        firstname_normalized = normalize_and_capitalize(firstname_part)
        lastname_normalized = normalize_and_capitalize(lastname_part)  # TODOS los apellidos

        # Enriquecer datos del candidato
        candidate[:firstname] = firstname_normalized
        candidate[:lastname1] = lastname_tokens[0]
        candidate[:lastname2] = lastname_tokens[1]

        # Crear fullname en formato Member (equivalente a member.fullname)
        # IMPORTANTE: Incluir TODOS los apellidos, no solo los primeros 2
        candidate[:fullname] = "#{firstname_normalized} #{lastname_normalized}".strip

        # Normalizar para búsqueda (sin acentos, sin mayúsculas, sin Ñ)
        candidate[:fullname_search] = normalize_for_search(candidate[:fullname])

        # Guardar original OFAC como referencia (solo para display)
        candidate[:ofac_raw] = name
      end

      valid
    end
  end

  # ============================================================
  # VALIDACIÓN 3: Excluir ya revisados en OfacCandidate
  # ============================================================
  def self.filter_not_reviewed(valid_candidates)
    # Obtener todos los candidatos ya revisados (normalizados en Ruby)
    reviewed = OfacCandidate.pluck(:ofac_name).map { |name| normalize_for_search(name) }

    valid_candidates.reject do |candidate|
      # Comparar normalizando ambos lados en Ruby (transliterate maneja TODOS los acentos)
      reviewed.include?(candidate[:fullname_search])
    end
  end

  # ============================================================
  # Funciones de Normalización
  # ============================================================

  # Normaliza y capitaliza: transliterar + Title Case
  # "MARÍA GARCÍA" → "Maria Garcia"
  def self.normalize_and_capitalize(text)
    I18n.transliterate(text.to_s.strip).split.map(&:capitalize).join(" ")
  end

  # Normaliza para búsqueda: transliterar + lowercase
  # Elimina acentos, ñ, mayúsculas para comparación robusta
  # "Maria García" → "maria garcia"
  # "Marco VILLELA" → "marco villela"
  def self.normalize_for_search(text)
    I18n.transliterate(text.to_s.strip.downcase)
  end
end

# ============================================================
# EJECUCIÓN
# ============================================================

if __FILE__ == $0
  candidate = OfacPipeline::Step1.execute!

  if candidate.nil?
    exit 1
  else
    exit 0
  end
end
