require 'net/http'
require 'uri'
require 'nokogiri'

API_KEY = '7F4T3OWDZ2MS5CJN7RF6K7E9XVTBR0RFXXZYQD9U5C2G430S09JTMLUCKTQRUQRG3B292VW5RC6O6FUK' # ← reemplazá con tu clave real

def build_duckduckgo_search_url(query)
  base_url = 'https://html.duckduckgo.com/html/' # versión HTML pura de DuckDuckGo
  "#{base_url}?q=#{URI.encode_www_form_component(query)}"
end

def fetch_html_with_scrapingbee(url)
  uri = URI('https://app.scrapingbee.com/api/v1/')
  params = {
    api_key: API_KEY,
    url: url,
    render_js: false, # DuckDuckGo no necesita JS
    block_resources: true # optimiza el scraping
  }
  uri.query = URI.encode_www_form(params)

  res = Net::HTTP.get_response(uri)

  html = res.body
  html.force_encoding('UTF-8')
  html.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
end

def extract_links_from_duckduckgo(html)
  doc = Nokogiri::HTML(html)
  links = []

  doc.css('a.result__a').each do |a|
    href = a['href']
    if href.include?('guerrero.quadratin.com.mx')
      links << href
    end
  end

  links.uniq
end

# === MAIN ===

query = 'Los Ardillos site:guerrero.quadratin.com.mx 2024'
all_links = []

puts "\n🔍 Buscando en DuckDuckGo: #{query}"

url = build_duckduckgo_search_url(query)
html = fetch_html_with_scrapingbee(url)
File.write("Ardillos_2024.html", html)

links = extract_links_from_duckduckgo(html)
puts "  ↳ Se encontraron #{links.size} enlaces:"
puts links

all_links.concat(links)

puts "\n✅ Total de links únicos encontrados: #{all_links.uniq.size}"