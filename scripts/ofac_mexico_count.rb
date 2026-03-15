# frozen_string_literal: true
require "set"
require "csv"
require "open-uri"
require "fileutils"
require "set"
require "digest"

BASE = "https://www.treasury.gov/ofac/downloads"
FILES = {
  "sdn.csv" => "#{BASE}/sdn.csv",
  "add.csv" => "#{BASE}/add.csv",
}

DATA_DIR = Rails.root.join("tmp", "ofac_data")

def download(url, dest)
  # User-Agent para evitar respuestas “raras”
  headers = {
    "User-Agent" => "Mozilla/5.0 (compatible; Ruby OFAC downloader; +https://sanctionssearch.ofac.treas.gov/)"
  }

  URI.open(url, headers) do |remote|
    body = remote.read
    File.binwrite(dest, body)
  end
end

def assert_looks_like_ofac_csv!(path, label)
  first = File.open(path, "rb") { |f| f.read(400) } || ""

  if first.strip.start_with?("<!DOCTYPE html", "<html", "<?xml")
    raise "#{label} parece HTML/XML (no CSV). Probable redirect/403. Revisa el contenido de #{path}."
  end

  # Primera “línea” debería tener comas y dígitos al inicio (ENT_NUM)
  line1 = first.split(/\r?\n/).first.to_s
  unless line1.include?(",") && line1.match?(/\A\s*\d+\s*,/)
    raise "#{label} no luce como CSV OFAC (línea 1: #{line1[0,120].inspect}). Revisa #{path}."
  end
end

FileUtils.mkdir_p(DATA_DIR)

FILES.each do |name, url|
  path = DATA_DIR.join(name)
  puts "Downloading #{name}..."
  download(url, path)

  puts "  saved to: #{path}"
  puts "  bytes: #{File.size(path)}  sha256: #{Digest::SHA256.file(path).hexdigest[0,16]}..."
end

sdn_path = DATA_DIR.join("sdn.csv")
add_path = DATA_DIR.join("add.csv")

assert_looks_like_ofac_csv!(sdn_path, "sdn.csv")
assert_looks_like_ofac_csv!(add_path, "add.csv")

# --- Parse SDN: ENT_NUM + SDN_TYPE (col 0 y 2) ---
individual_ent_nums = Set.new
sdn_rows = 0

CSV.foreach(sdn_path, headers: false, encoding: "bom|utf-8") do |row|
  next if row.nil? || row.empty?
  sdn_rows += 1

  ent_num = row[0].to_s.strip
  sdn_type = row[2].to_s.strip.upcase
  individual_ent_nums.add(ent_num) if sdn_type == "INDIVIDUAL"
end

# --- Parse ADD: ENT_NUM + COUNTRY (col 0 y 6) ---
mexico_individuals = Set.new

# --- Parse ADD: ENT_NUM + COUNTRY (col 0 y 4 en tu add.csv) ---
add_rows = 0
country_rows = Hash.new(0)                 # filas de direcciones por país (para referencia)
individuals_by_country = Hash.new { |h,k| h[k] = Set.new }  # individuos únicos por país

CSV.foreach(add_path, headers: false, encoding: "bom|utf-8") do |row|
  next if row.nil?
  next if row.length == 1 && row[0].to_s.include?("\u001A")
  next if row.length < 5

  add_rows += 1

  ent_num = row[0].to_s.strip
  country = row[4].to_s.strip
  next if country.empty? || country == "-0-"

  country_rows[country] += 1

  # Solo nos interesan individuos SDN
  next unless individual_ent_nums.include?(ent_num)

  # Un individuo cuenta 1 vez por país (aunque tenga varias direcciones)
  individuals_by_country[country].add(ent_num)
end

puts
puts "ADD rows: #{add_rows}"

# Tabla: individuos únicos por país (descendente)
puts
puts "Individuals (SDN_TYPE=INDIVIDUAL) con >=1 dirección por país (unique ENT_NUM):"
puts "-" * 72
puts format("%-35s %10s %14s", "Country", "Individuals", "ADD rows")
puts "-" * 72

individuals_by_country
  .map { |country, set| [country, set.size, country_rows[country]] }
  .sort_by { |country, ind_count, add_count| [-ind_count, -add_count, country] }
  .each do |country, ind_count, add_count|
    puts format("%-35s %10d %14d", country, ind_count, add_count)
  end

# =========================
# MATCH OFAC MÉXICO vs Member
# =========================

def norm_str(str)
  I18n.transliterate(str.to_s.strip.downcase).squeeze(" ")
end

def split_ofac_name(full_name)
  raw = full_name.to_s.strip
  return { raw: raw, firstname: "", lastname1: "", lastname2: "" } if raw.blank?

  cleaned = raw.gsub(/\s+/, " ").strip

  if cleaned.include?(",")
    last_part, first_part = cleaned.split(",", 2).map(&:strip)
    last_tokens  = norm_str(last_part).split
    first_tokens = norm_str(first_part).split

    {
      raw: raw,
      firstname: first_tokens.join(" "),
      lastname1: last_tokens[0].to_s,
      lastname2: last_tokens[1..]&.join(" ").to_s
    }
  else
    tokens = norm_str(cleaned).split

    if tokens.length >= 3
      {
        raw: raw,
        firstname: tokens[0..-3].join(" "),
        lastname1: tokens[-2].to_s,
        lastname2: tokens[-1].to_s
      }
    elsif tokens.length == 2
      {
        raw: raw,
        firstname: tokens[0].to_s,
        lastname1: tokens[1].to_s,
        lastname2: ""
      }
    else
      {
        raw: raw,
        firstname: tokens[0].to_s,
        lastname1: "",
        lastname2: ""
      }
    end
  end
end

def token_match(input, candidate)
  return false if candidate.blank?
  return true if input.blank?
  input.include?(candidate) || candidate.include?(input)
end

# 1) ENT_NUM de individuos OFAC con domicilio en México
mexico_ent_nums = individuals_by_country["Mexico"] || Set.new

# 2) Mapa ENT_NUM -> nombre OFAC
ofac_mexico_people = []

CSV.foreach(sdn_path, headers: false, encoding: "bom|utf-8") do |row|
  next if row.nil? || row.empty?

  ent_num   = row[0].to_s.strip
  full_name = row[1].to_s.strip
  sdn_type  = row[2].to_s.strip.upcase

  next unless sdn_type == "INDIVIDUAL"
  next unless mexico_ent_nums.include?(ent_num)

  parsed = split_ofac_name(full_name)

  ofac_mexico_people << {
    ent_num: ent_num,
    full_name: full_name,
    firstname: parsed[:firstname],
    lastname1: parsed[:lastname1],
    lastname2: parsed[:lastname2]
  }
end

ofac_mexico_people.uniq! { |p| p[:ent_num] }

# 3) Universo base, igual que tu members_query
base_scope = Member.joins(:hits).distinct

members = base_scope
  .select(:id, :firstname, :lastname1, :lastname2, :alias)
  .preload(:fake_identities)
  .to_a

matched = []
unmatched = []

ofac_mexico_people.each do |person|
  input_firstname = norm_str(person[:firstname])
  input_lastname1 = norm_str(person[:lastname1])
  input_lastname2 = norm_str(person[:lastname2])

  possible_matches = members.select do |member|
    real_match =
      token_match(input_firstname, norm_str(member.firstname)) &&
      token_match(input_lastname1, norm_str(member.lastname1)) &&
      token_match(input_lastname2, norm_str(member.lastname2))

    fake_match = member.fake_identities.any? do |fi|
      token_match(input_firstname, norm_str(fi.firstname)) &&
      token_match(input_lastname1, norm_str(fi.lastname1)) &&
      token_match(input_lastname2, norm_str(fi.lastname2))
    end

    real_match || fake_match
  end

  if possible_matches.any?
    matched << {
      ofac_name: person[:full_name],
      ent_num: person[:ent_num],
      member_names: possible_matches.map(&:fullname).uniq
    }
  else
    unmatched << {
      ofac_name: person[:full_name],
      ent_num: person[:ent_num]
    }
  end
end

# 4) Impresión en consola

puts
puts "=" * 90
puts "1. PERSONAS OFAC (DOMICILIO EN MÉXICO) CON POSIBLE MATCH EN LA BASE"
puts "=" * 90

if matched.empty?
  puts "No se identificaron posibles matches."
else
  matched.each_with_index do |row, idx|
    puts "#{idx + 1}. #{row[:ofac_name]}  [ENT_NUM=#{row[:ent_num]}]"
    puts "   Posibles matches: #{row[:member_names].join(' | ')}"
  end
end

puts
puts "=" * 90
puts "2. PERSONAS OFAC (DOMICILIO EN MÉXICO) SIN MATCH IDENTIFICADO EN LA BASE"
puts "=" * 90

if unmatched.empty?
  puts "Todas tuvieron al menos un posible match."
else
  unmatched.each_with_index do |row, idx|
    puts "#{idx + 1}. #{row[:ofac_name]}  [ENT_NUM=#{row[:ent_num]}]"
  end
end

puts
puts "=" * 90
puts "3. RESUMEN"
puts "=" * 90
puts format("%-35s %10d", "OFAC México - total personas", ofac_mexico_people.size)
puts format("%-35s %10d", "Con posible match", matched.size)
puts format("%-35s %10d", "Sin match", unmatched.size)