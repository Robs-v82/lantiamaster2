require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'

API_KEY = 'TU_API_KEY_DE_SCRAPINGBEE' # ← Reemplaza esto por tu API key
BASE_URL = 'https://www.milenio.com/buscador'

# Construye URL de búsqueda con palabra clave y año
def build_search_url(query, year, page)
  fecha = "#{year}"
  "#{BASE_URL}?q=#{URI.encode_www_form_component(query)}+#{fecha}&page=#{page}"
end

# Llama a ScrapingBee con renderizado de JS (por si Milenio carga dinámicamente)
def fetch_html_with_scrapingbee(url)
  uri = URI('https://app.scrapingbee.com/api/v1/')
  params = {
    api_key: API_KEY,
    url: url,
    render_js: true # ← importante para que cargue bien
  }
  uri.query = URI.encode_www_form(params)

  res = Net::HTTP.get_response(uri)
  body = res.body

  # Encoding a UTF-8 limpio
  body.force_encoding('UTF-8')
  body = body.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')

  body
end

# Extrae enlaces relevantes a notas de Milenio (evita otros links)
def extract_article_links(html)
  doc = Nokogiri::HTML(html)
  links = []

  doc.css('a').each do |a|
    href = a['href']
    next unless href

    # Filtra solo URLs que parecen ser notas
    if href.match?(/^\/[a-z\-]+\/[a-z0-9\-]+\/[a-z0-9\-]+$/)
      full_url = href.start_with?('http') ? href : "https://www.milenio.com#{href}"
      links << full_url
    end
  end

  links.uniq
end

# === MAIN ===

query = 'CJNG'
year = 2023
total_pages = 500 # Podés aumentarlo si querés más profundidad
all_links = []

(1..total_pages).each do |page|
  search_url = build_search_url(query, year, page)
  puts "\n🔎 Página #{page}: #{search_url}"

  html = fetch_html_with_scrapingbee(search_url)
  links = extract_article_links(html)

  puts "  ↳ Se encontraron #{links.size} links"
  all_links.concat(links)

  sleep(2) # Respeto para la API
end

puts "\n✅ Total de links únicos encontrados: #{all_links.uniq.size}"
puts all_links.uniq