#!/usr/bin/env ruby
# frozen_string_literal: true

# wrongRecords.rb
# Lee scripts/PERFILOC.csv y detecta strings en columnas 7..10
# que no coinciden EXACTAMENTE con algún "nombre maestro" de la columna 0.

require 'csv'
require 'set'

# Permite pasar la ruta del CSV por argumento; por defecto usa scripts/PERFILOC.csv
csv_path = ARGV[0] || File.join('scripts', 'PERFILOC.csv')

unless File.exist?(csv_path)
  warn "No se encontró el archivo CSV en: #{csv_path}"
  exit 1
end

# 1) Primer pase: recolectar todos los nombres maestros (columna 0)
master_names = Set.new

CSV.foreach(csv_path, headers: false, encoding: 'bom|utf-8') do |row|
  next if row.nil?
  master = row[0].to_s.strip
  master_names.add(master) unless master.empty?
end

# 2) Segundo pase: revisar columnas 7..10 y acumular no-coincidentes
wrongStrings = []  # solicitado explícitamente como array

CSV.foreach(csv_path, headers: false, encoding: 'bom|utf-8') do |row|
  next if row.nil?

  (7..10).each do |idx|
    cell = row[idx]
    next if cell.nil? || cell.to_s.strip.empty?

    cell.to_s.split(';').each do |raw|
      s = raw.to_s.strip
      next if s.empty?
      wrongStrings << s unless master_names.include?(s)
    end
  end
end

# 3) Únicos y salida
unique_wrong = wrongStrings.uniq.sort

puts "WRONG STRINGS (#{unique_wrong.size} únicos):"
unique_wrong.each { |s| puts s }
