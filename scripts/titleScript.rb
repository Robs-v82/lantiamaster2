require_relative '../config/environment'
require 'httparty'
require 'json'
require 'csv'

# Paso 1: Obtener miembros con hits
myMembers = Member.joins(:hits).distinct

# Paso 2: Cargar frecuencias
name_frequencies = Name.all.pluck(:word, :freq).map { |w, f| [I18n.transliterate(w).downcase.strip, f] }.to_h

# Paso 3: Normalizador
def normalize_name(str)
  I18n.transliterate(str.to_s).downcase.strip
end

# Paso 4: Seleccionar miembros con baja probabilidad de homónimos
targetMembers = myMembers.select do |member|
  first = normalize_name(member.firstname)
  last1 = normalize_name(member.lastname1)
  last2 = normalize_name(member.lastname2)

  valid = [first, last1, last2].all? { |n| n.match?(/\A[a-zñü\s]{2,}\z/) }
  next false unless valid

  f1 = name_frequencies[first] || 5
  f2 = name_frequencies[last1] || 5
  f3 = name_frequencies[last2] || 5

  ((f1 * f2 * f3) / 10000.0).round < 2
end

puts "Miembros objetivo con baja probabilidad de homónimos: #{targetMembers.count}"




