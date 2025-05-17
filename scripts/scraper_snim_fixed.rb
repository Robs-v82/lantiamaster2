
require 'httparty'
require 'nokogiri'
require 'csv'
require 'fileutils'

# URL de destino
SNIM_URL = 'http://www.snim.rami.gob.mx/cgi-bin/web.cgi'
HEADERS = { 'Content-Type' => 'application/x-www-form-urlencoded' }

# Rutas de entrada y salida
MUNICIPIOS_CSV = 'municipios.csv'
HTML_DIR = 'html_municipios'

# Crear carpeta de salida
FileUtils.mkdir_p(HTML_DIR)

# Cargar municipios válidos
municipios_validos = []
CSV.foreach(MUNICIPIOS_CSV, headers: true) do |row|
  full_code = row['full_code'].to_s.rjust(5, '0')
  estado_id = full_code[0..1]
  municipio_id = full_code[2..4]

  municipios_validos << {
    estado_nombre: row['state.name'],
    municipio_nombre: row['name'].to_s.strip,
    estado_id: estado_id,
    municipio_id: municipio_id,
    full_code: full_code
  }
end

# Llevar registro de fallos
no_descargados = []

municipios_validos.each do |m|
  next if m[:municipio_id].nil? || m[:estado_id].nil?
  print m[:estado_nombre]
  print m[:municipio_nombre]
  begin
    response = HTTParty.post(SNIM_URL,
      headers: HEADERS,
      body: {
        "estado1" => m[:estado_id].to_i.to_s,
        "municipio1" => m[:municipio_id].to_i.to_s,
        "buscar" => "Consultar"
      }
    )

    if response.code == 200 && response.body.include?("<table")
      estado_safe = m[:estado_nombre].gsub(/\s+/, '_').downcase
      municipio_safe = m[:municipio_nombre].gsub(/\s+/, '_').downcase
      File.write("\#{HTML_DIR}/\#{estado_safe}__\#{municipio_safe}.html", response.body)
      puts "✔️ Guardado: \#{estado_safe} / \#{municipio_safe}"
    else
      no_descargados << m
      puts "⚠️  No se encontró tabla para: \#{m[:estado_nombre]} / \#{m[:municipio_nombre]}"
    end

  rescue => e
    puts "❌ Error con: \#{m[:estado_nombre]} / \#{m[:municipio_nombre]} - \#{e.message}"
    no_descargados << m
  end
end

# Imprimir municipios no descargados
if no_descargados.any?
  puts "\n--- Municipios NO descargados ---"
  no_descargados.each do |fail|
    puts "\#{fail[:estado_nombre]} / \#{fail[:municipio_nombre]}"
  end
end
