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

# Paso 5: Cliente HTTParty
class CedulaClient
  include HTTParty
  base_uri 'https://www.cedulaprofesional.sep.gob.mx'

  def initialize
    @headers = {
      'User-Agent' => 'Mozilla/5.0',
      'Content-Type' => 'application/json;charset=UTF-8',
      'X-Requested-With' => 'XMLHttpRequest',
      'Accept' => 'application/json, text/javascript, */*; q=0.01',
      'Referer' => 'https://www.cedulaprofesional.sep.gob.mx/cedula/presidencia/indexAvanzada.action',
      'Origin' => 'https://www.cedulaprofesional.sep.gob.mx'
    }

    # Simula una visita inicial para obtener cookies
    self.class.get('/cedula/presidencia/indexAvanzada.action', headers: @headers)
    @cookies = self.class.cookies
  end

  def buscar(nombre:, paterno:, materno: nil)
    body = {
      maxResult: "1000",
      nombre: nombre,
      paterno: paterno,
      materno: materno || "",
      idCedula: ""
    }.to_json

    response = self.class.post(
      '/cedula/buscaCedulaJson.action',
      body: body,
      headers: @headers,
      cookies: @cookies
    )

    raise "Respuesta vacía" if response.body.strip.empty?

    JSON.parse(response.body)["items"] || []
  rescue => e
    puts "❌ Error al consultar #{nombre} #{paterno} #{materno}: #{e.message}"
    []
  end
end

client = CedulaClient.new

targetMembers = Member.where(:firstname=>"Roberto", :lastname1=>"Valladares", :lastname2=>"Piedras")

targetMembers.each do |member|
# targetMembers.first(100).each do |member|
  nombre  = member.firstname.upcase
  paterno = member.lastname1.upcase
  materno = member.lastname2&.upcase

  puts "\n🔍 Buscando: #{nombre} #{paterno} #{materno}"

  resultados = client.buscar(nombre: nombre, paterno: paterno, materno: materno)

  if resultados.empty?
    puts "❌ Sin resultados"
  else
    resultados.each do |r|
      if r["nombre"] == nombre && r["paterno"] == paterno && r["materno"] == materno
        puts "✅ Cédula: #{r['idCedula']} | #{r['titulo']} | #{r['desins']} (#{r['tipo']})"
      else
        puts "ℹ️ Coincidencia parcial: #{r['nombre']} #{r['paterno']} #{r['materno']} → cédula #{r['idCedula']}"
      end
    end
  end
end


