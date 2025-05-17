
require 'nokogiri'
require 'csv'
require 'open-uri'

# Ruta al archivo CSV de municipios
MUNICIPIOS_CSV = 'municipios.csv' # Debe contener las columnas: state.code, name, full_code

# Ruta base de archivos HTML descargados por municipio
HTML_DIR = 'html_municipios' # Carpeta donde se guardan los archivos HTML

# Ruta de salida del archivo consolidado
OUTPUT_CSV = 'presidentes_municipales_consolidado.csv'

# Cargar claves INEGI
municipios = {}
CSV.foreach(MUNICIPIOS_CSV, headers: true) do |row|
  key = [row['state.code'].to_s.strip.downcase, row['name'].to_s.strip.downcase]
  municipios[key] = row['full_code']
end

# Encabezados de la salida
output = CSV.generate(headers: true) do |csv|
  csv << ['full_code', 'Estado', 'Municipio', 'Presidente Municipal', 'Sexo', 'Periodo', 'Partido']

  Dir.glob("\#{HTML_DIR}/*.html").each do |file|
    # Inferir estado y municipio desde el nombre del archivo
    parts = File.basename(file, '.html').split('__') # Formato esperado: estado__municipio.html
    estado = parts[0].gsub('_', ' ')
    municipio = parts[1].gsub('_', ' ')
    estado_norm = estado.strip.downcase
    municipio_norm = municipio.strip.downcase

    # Buscar clave INEGI
    clave = municipios[[estado_norm, municipio_norm]]

    # Procesar HTML
    doc = Nokogiri::HTML(File.read(file))
    rows = doc.css('table tr')
    rows.shift # Quitar encabezado

    rows.each do |tr|
      tds = tr.css('td').map(&:text).map(&:strip)
      next unless tds.size >= 4
      csv << [clave, estado, municipio, *tds[0..3]]
    end
  end
end

# Guardar CSV
File.write(OUTPUT_CSV, output)
puts "Archivo generado: \#{OUTPUT_CSV}"
