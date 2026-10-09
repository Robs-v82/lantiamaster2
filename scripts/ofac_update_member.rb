#!/usr/bin/env ruby

# ============================================================
# OFAC Update Member Script
# Actualiza información OFAC para un Member específico
# Uso: bundle exec rails runner scripts/ofac_update_member.rb <member_id>
# ============================================================

require "set"
require "csv"
require "open-uri"
require "fileutils"

# Validar parámetro
member_id = ARGV[0]
unless member_id.present?
  puts "❌ Error: Debes proporcionar el ID del Member"
  puts "Uso: bundle exec rails runner scripts/ofac_update_member.rb <member_id>"
  exit 1
end

# Cargar Member
member = Member.find_by(id: member_id)
unless member.present?
  puts "❌ Error: Member ID #{member_id} no encontrado"
  exit 1
end

puts "\n" + "=" * 70
puts "🔄 OFAC Update Member: #{member.fullname} (ID: #{member_id})"
puts "=" * 70

BASE = "https://www.treasury.gov/ofac/downloads"

FILES = {
  "sdn.csv" => "#{BASE}/sdn.csv",
  "add.csv" => "#{BASE}/add.csv"
}

DATA_DIR = Rails.root.join("tmp", "ofac_data")
FileUtils.mkdir_p(DATA_DIR)

def download(url, dest)
  headers = { "User-Agent" => "Mozilla/5.0 (Ruby OFAC script)" }
  URI.open(url, headers.merge(ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)) do |remote|
    File.binwrite(dest, remote.read)
  end
end

# Descargar CSVs
puts "\n📥 Descargando CSVs de OFAC..."
FILES.each do |name, url|
  path = DATA_DIR.join(name)
  download(url, path)
  puts "   ✓ #{name}"
end

sdn_path = DATA_DIR.join("sdn.csv")
add_path = DATA_DIR.join("add.csv")

# ============================================================
# 1. Identificar INDIVIDUALES en SDN
# ============================================================

puts "\n🔍 Identificando individuales..."
individuals = {}

CSV.foreach(sdn_path, headers: false, encoding: "bom|utf-8") do |row|
  next if row.nil?

  ent_num = row[0].to_s.strip
  name = row[1].to_s.strip
  type = row[2].to_s.strip.upcase

  next unless type == "INDIVIDUAL"

  individuals[ent_num] = {
    name: name,
    dob: nil
  }
end

puts "   ✓ Total individuales encontrados: #{individuals.size}"

# ============================================================
# 2. Identificar MÉXICO
# ============================================================

puts "\n🗺️  Filtrando México..."
mexico_ent_nums = Set.new

CSV.foreach(add_path, headers: false, encoding: "bom|utf-8") do |row|
  next if row.nil?
  next if row.length < 5

  ent_num = row[0].to_s.strip
  country = row[4].to_s.strip

  next unless country == "Mexico"
  next unless individuals.key?(ent_num)

  mexico_ent_nums.add(ent_num)
end

puts "   ✓ Total México: #{mexico_ent_nums.size}"

# ============================================================
# 3. Extraer DOB desde SDN remarks
# ============================================================

def extract_dob_from_remarks(remarks)
  text = remarks.to_s.strip
  return nil if text.blank?

  if (m = text.match(/\bDOB\s+([^;]+)/i))
    m[1].strip
  else
    nil
  end
end

puts "\n📅 Extrayendo DOB..."
CSV.foreach(sdn_path, headers: false, encoding: "bom|utf-8") do |row|
  next if row.nil?

  ent_num = row[0].to_s.strip
  next unless individuals.key?(ent_num)

  remarks = row[11].to_s
  dob_text = extract_dob_from_remarks(remarks)

  individuals[ent_num][:dob] ||= dob_text if dob_text.present?
end

# ============================================================
# 4. Funciones de matching
# ============================================================

def normalize(str)
  I18n.transliterate(str.to_s.downcase.strip)
end

def match_token(a, b)
  return false if b.blank?
  return true if a.blank?
  a.include?(b) || b.include?(a)
end

def split_name(name)
  clean = name.gsub(/\s+/, " ").strip

  if clean.include?(",")
    last, first = clean.split(",", 2)
    last_normalized = normalize(last)
    first_normalized = normalize(first)

    last_tokens = last_normalized.split
    prepositions = ["de", "del", "da", "la", "el"]

    # PARTE 1: AGRUPAMIENTO MEJORADO
    # Cuando encuentres preposición, agrupa:
    # - todas las preposiciones consecutivas
    # - LUEGO la siguiente palabra
    grouped_last = []
    i = 0
    while i < last_tokens.length
      current = last_tokens[i]

      if prepositions.include?(current)
        group = current
        i += 1

        # Continúa con preposiciones/artículos consecutivos
        while i < last_tokens.length && prepositions.include?(last_tokens[i])
          group += " #{last_tokens[i]}"
          i += 1
        end

        # Agrupa la palabra que sigue
        if i < last_tokens.length
          group += " #{last_tokens[i]}"
          i += 1
        end

        grouped_last << group
      else
        grouped_last << current
        i += 1
      end
    end

    # PARTE 2: POST-PROCESAMIENTO BIDIRECCIONAL
    # Si hay 3+ grupos, combina inteligentemente
    if grouped_last.length >= 3
      new_grouped = []
      i = 0

      while i < grouped_last.length
        current_group = grouped_last[i]
        has_prep_current = prepositions.any? { |p| current_group.include?(" #{p} ") || current_group.start_with?(p) }

        if i + 1 < grouped_last.length
          next_group = grouped_last[i + 1]
          has_prep_next = prepositions.any? { |p| next_group.include?(" #{p} ") || next_group.start_with?(p) }

          # Combina si: actual tiene prep y siguiente es palabra, O actual es palabra y siguiente tiene prep
          if (has_prep_current && !has_prep_next) || (!has_prep_current && has_prep_next)
            new_grouped << "#{current_group} #{next_group}"
            i += 2
          else
            new_grouped << current_group
            i += 1
          end
        else
          new_grouped << current_group
          i += 1
        end
      end

      grouped_last = new_grouped
    end

    first_tokens = first_normalized.split

    {
      firstname: first_tokens.join(" "),
      lastname1: grouped_last[0],
      lastname2: grouped_last[1]
    }
  else
    tokens = normalize(clean).split

    {
      firstname: tokens[0],
      lastname1: tokens[1],
      lastname2: tokens[2]
    }
  end
end

# ============================================================
# 5. Buscar match para este Member
# ============================================================

puts "\n🔎 Buscando match para #{member.fullname}..."

match_found = false
match_ent_num = nil
match_dob = nil

mexico_ent_nums.each do |ent_num|
  ofac = individuals[ent_num]
  parsed = split_name(ofac[:name])

  input_firstname = parsed[:firstname]
  input_lastname1 = parsed[:lastname1]
  input_lastname2 = parsed[:lastname2]

  # Comparar con Member real
  real_match =
    match_token(input_firstname, normalize(member.firstname)) &&
    match_token(input_lastname1, normalize(member.lastname1)) &&
    match_token(input_lastname2, normalize(member.lastname2))

  # Comparar con fake identities
  fake_match = member.fake_identities.any? do |fi|
    match_token(input_firstname, normalize(fi.firstname)) &&
    match_token(input_lastname1, normalize(fi.lastname1)) &&
    match_token(input_lastname2, normalize(fi.lastname2))
  end

  if real_match || fake_match
    match_found = true
    match_ent_num = ent_num
    match_dob = begin
      Date.parse(ofac[:dob]) rescue nil
    end

    puts "\n   ✓ MATCH ENCONTRADO"
    puts "   OFAC Name: #{ofac[:name]}"
    puts "   OFAC ENT_NUM: #{ent_num}"
    puts "   OFAC DOB: #{ofac[:dob]} (parsed: #{match_dob})"

    break
  end
end

# ============================================================
# 6. Actualizar Member
# ============================================================

if match_found
  attrs = {
    ofac_designation: true,
    ofac_ent_num: match_ent_num
  }

  attrs[:birthday] = match_dob if match_dob.present? && member.birthday != match_dob

  member.update(attrs)

  puts "\n✅ Member actualizado:"
  puts "   ofac_designation: true"
  puts "   ofac_ent_num: #{match_ent_num}"
  puts "   birthday: #{match_dob}" if match_dob.present?
else
  puts "\n❌ No se encontró match en OFAC México para este Member"
end

puts "\n" + "=" * 70
puts "✅ Script completado"
puts "=" * 70
