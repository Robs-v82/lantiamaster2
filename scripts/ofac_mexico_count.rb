# frozen_string_literal: true

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

add_rows = 0
mexico_add_rows = 0

CSV.foreach(add_path, headers: false, encoding: "bom|utf-8") do |row|
  next if row.nil?
  next if row.length == 1 && row[0].to_s.include?("\u001A")
  next if row.length < 5

  add_rows += 1  # <-- aquí, antes de filtrar

  ent_num = row[0].to_s.strip
  country = row[4].to_s.strip.upcase # <-- en tu add.csv, COUNTRY está en [4]

  next unless country == "MEXICO"
  mexico_add_rows += 1

  next unless individual_ent_nums.include?(ent_num)
  mexico_individuals.add(ent_num)
end

puts
puts "SDN rows: #{sdn_rows}"
puts "Individuals in SDN: #{individual_ent_nums.size}"
puts "ADD rows: #{add_rows}"
puts "ADD rows with country == MEXICO: #{mexico_add_rows}"
puts "Individuals con alguna dirección en MEXICO: #{mexico_individuals.size}"