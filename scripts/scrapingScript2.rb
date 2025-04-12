require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'

API_KEY = '7F4T3OWDZ2MS5CJN7RF6K7E9XVTBR0RFXXZYQD9U5C2G430S09JTMLUCKTQRUQRG3B292VW5RC6O6FUK'
BASE_URL = 'https://www.milenio.com/buscador'

def build_search_url(query, page)
  # Milenio usa parámetros como estos en su buscador
  "#{BASE_URL}?q=#{URI.encode(query)}&page=#{page}"
end

def fetch_html_with_scrapingbee(url)
  uri = URI('https://app.scrapingbee.com/api/v1/')
  params = {
    api_key: API_KEY,
    url: url,
    render_js: false # Si el sitio carga con JS, cambia a true
  }
  uri.query = URI.encode_www_form(params)

  res = Net::HTTP.get_response(uri)
  res.body
end

def extract_article_links(html)
  doc = Nokogiri::HTML(html)
  links = []

  # Este selector depende del HTML de Milenio, puede cambiar
  doc.css('a').each do |a|
    href = a['href']
    if href && href.include?('/politica/') || href.include?('/nacional/') || href.include?('/internacional/')
      links << "https://www.milenio.com#{href}" unless href.start_with?('http')
    end
  end

  links.uniq
end

# === PARTE PRINCIPAL ===

query = 'fentanilo' # o cualquier palabra clave
total_pages = 3 # ajusta según lo que quieras recorrer

all_links = []

(1..total_pages).each do |page|
  search_url = build_search_url(query, page)
  puts "Consultando página #{page}: #{search_url}"

  html = fetch_html_with_scrapingbee(search_url)
  links = extract_article_links(html)
  all_links.concat(links)
  sleep(2) # para no abusar de la API
end

puts "Se encontraron #{all_links.uniq.size} links:"
puts all_links.uniq