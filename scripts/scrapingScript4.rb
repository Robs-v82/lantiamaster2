require 'net/http'
require 'uri'
require 'json'
require 'nokogiri'

API_KEY = '7F4T3OWDZ2MS5CJN7RF6K7E9XVTBR0RFXXZYQD9U5C2G430S09JTMLUCKTQRUQRG3B292VW5RC6O6FUK' # <- reemplaza por tu clave real
GOOGLE_SEARCH_URL = 'https://www.google.com/search'

def build_google_search_url(query, start)
  q = URI.encode_www_form_component(query)
  "#{GOOGLE_SEARCH_URL}?q=#{q}&start=#{start}"
end

def fetch_html_with_scrapingbee(url)
  uri = URI('https://app.scrapingbee.com/api/v1/')

  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'

  # Este es el cuerpo CORRECTO, incluyendo api_key como clave
  request.body = {
    api_key: API_KEY,
    url: url,
    render_js: true,
    premium_proxy: true,
    headers: {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }
  }.to_json

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  body = response.body
  body.force_encoding('UTF-8')
  body.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
end

def extract_links_from_google(html)
  doc = Nokogiri::HTML(html)
  links = []

  doc.css('a').each do |a|
    href = a['href']
    next unless href

    if href.include?('/url?q=https://www.milenio.com')
      clean_url = href[/\/url\?q=(.*?)&/, 1]
      links << clean_url if clean_url
    end
  end

  links.uniq
end

# === MAIN ===

query = 'CJNG site:milenio.com 2023'
pages = 2
all_links = []

(0...pages).each do |i|
  start = i * 10
  url = build_google_search_url(query, start)

  puts "\n🔍 Página #{i + 1}: #{url}"

  html = fetch_html_with_scrapingbee(url)
  File.write("pagina_google_#{i + 1}.html", html)

  links = extract_links_from_google(html)
  puts "  ↳ Se encontraron #{links.size} enlaces"
  all_links.concat(links)

  sleep(2)
end

puts "\n✅ Total de links únicos encontrados: #{all_links.uniq.size}"
puts all_links.uniq
