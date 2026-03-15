require "set"
require "csv"
require "open-uri"
require "fileutils"
require "digest"

BASE = "https://www.treasury.gov/ofac/downloads"

FILES = {
  "sdn.csv" => "#{BASE}/sdn.csv",
  "add.csv" => "#{BASE}/add.csv",
  "alt.csv" => "#{BASE}/alt.csv"
}

DATA_DIR = Rails.root.join("tmp", "ofac_data")

FileUtils.mkdir_p(DATA_DIR)

def download(url, dest)
  headers = {
    "User-Agent" => "Mozilla/5.0 (Ruby OFAC script)"
  }

  URI.open(url, headers) do |remote|
    File.binwrite(dest, remote.read)
  end
end

FILES.each do |name, url|
  path = DATA_DIR.join(name)
  puts "Downloading #{name}..."
  download(url, path)
end

sdn_path = DATA_DIR.join("sdn.csv")
add_path = DATA_DIR.join("add.csv")
alt_path = DATA_DIR.join("alt.csv")

# =========================
# 1. Identificar INDIVIDUAL
# =========================

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

# =========================
# 2. Identificar México
# =========================

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

# =========================
# 3. Extraer DOB desde SDN remarks
# =========================

def extract_dob_from_remarks(remarks)
  text = remarks.to_s.strip
  return nil if text.blank?

  # Ejemplo típico OFAC: "DOB 17 Jan 1941; POB ..."
  if (m = text.match(/\bDOB\s+([^;]+)/i))
    m[1].strip
  else
    nil
  end
end

CSV.foreach(sdn_path, headers: false, encoding: "bom|utf-8") do |row|
  next if row.nil?

  ent_num = row[0].to_s.strip
  next unless individuals.key?(ent_num)

  remarks = row[11].to_s
  dob_text = extract_dob_from_remarks(remarks)

  individuals[ent_num][:dob] ||= dob_text if dob_text.present?
end

# =========================
# 4. Funciones de matching
# =========================

def normalize(str)
  I18n.transliterate(str.to_s.downcase.strip)
end

def match_token(a,b)
  return false if b.blank?
  return true if a.blank?
  a.include?(b) || b.include?(a)
end

def split_name(name)
  clean = name.gsub(/\s+/," ").strip

  if clean.include?(",")
    last, first = clean.split(",",2)
    last_tokens = normalize(last).split
    first_tokens = normalize(first).split

    {
      firstname: first_tokens.join(" "),
      lastname1: last_tokens[0],
      lastname2: last_tokens[1]
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

# =========================
# 5. Cargar universo Member
# =========================

members = Member
  .joins(:hits).distinct
  .select(:id,:firstname,:lastname1,:lastname2,:birthday)
  .preload(:fake_identities)
  .to_a

updated = []
no_match = []

# =========================
# 6. Matching
# =========================

mexico_ent_nums.each do |ent_num|

  ofac = individuals[ent_num]
  parsed = split_name(ofac[:name])

  input_firstname = parsed[:firstname]
  input_lastname1 = parsed[:lastname1]
  input_lastname2 = parsed[:lastname2]

  match_member = members.find do |m|

    real_match =
      match_token(input_firstname, normalize(m.firstname)) &&
      match_token(input_lastname1, normalize(m.lastname1)) &&
      match_token(input_lastname2, normalize(m.lastname2))

    fake_match = m.fake_identities.any? do |fi|
      match_token(input_firstname, normalize(fi.firstname)) &&
      match_token(input_lastname1, normalize(fi.lastname1)) &&
      match_token(input_lastname2, normalize(fi.lastname2))
    end

    real_match || fake_match
  end

  if match_member
    dob = begin
      Date.parse(ofac[:dob]) rescue nil
    end

    attrs = {
      ofac_designation: true,
      ofac_ent_num: ent_num
    }

    attrs[:birthday] = dob if dob.present? && match_member.birthday != dob

    puts "OFAC: #{ofac[:name]} | ENT_NUM: #{ent_num} | DOB raw: #{ofac[:dob].inspect} | DOB parsed: #{dob.inspect}"

    match_member.update(attrs)

    updated << {
      ofac: ofac[:name],
      member: match_member.fullname,
      dob: dob
    }
  else
    no_match << ofac[:name]
  end
end

# =========================
# 7. Output
# =========================

puts
puts "MATCHES ENCONTRADOS"
puts "-"*60

updated.each do |row|
  puts "#{row[:ofac]}  ->  #{row[:member]}"
end

puts
puts "SIN MATCH"
puts "-"*60

no_match.each do |name|
  puts name
end

# =========================
# 8. Desmarcar members que ya no aparecen en OFAC México
# =========================

removed = []

Member.where(ofac_designation: true).where.not(ofac_ent_num: [nil, ""]).find_each do |member|
  unless mexico_ent_nums.include?(member.ofac_ent_num.to_s)
    member.update(
      ofac_designation: false,
      ofac_ent_num: nil
    )

    removed << member.fullname
  end
end

puts
puts "DESMARCADOS POR YA NO APARECER EN OFAC MEXICO"
puts "-" * 60

if removed.any?
  removed.each { |name| puts name }
else
  puts "No hubo registros para desmarcar."
end

puts
puts "RESUMEN FINAL"
puts "-" * 60
puts "OFAC Mexico total: #{mexico_ent_nums.size}"
puts "Con match: #{updated.size}"
puts "Sin match: #{no_match.size}"
puts "Desmarcados: #{removed.size}"