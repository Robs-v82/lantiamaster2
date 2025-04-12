require 'net/http'
require 'uri'
require 'nokogiri'

API_KEY = '7F4T3OWDZ2MS5CJN7RF6K7E9XVTBR0RFXXZYQD9U5C2G430S09JTMLUCKTQRUQRG3B292VW5RC6O6FUK'
GOOGLE_SEARCH_URL = 'https://www.google.com/search'

def build_google_search_url(query, start)
  q = URI.encode_www_form_component(query)
  "#{GOOGLE_SEARCH_URL}?q=#{q}&start=#{start}"
end

def fetch_html_with_scrapingbee(url)
  uri = URI('https://app.scrapingbee.com/api/v1/')
  params = {
    api_key: API_KEY,
    url: url,
    render_js: true,
    premium_proxy: true,
    custom_google: true
  }
  uri.query = URI.encode_www_form(params)

  res = Net::HTTP.get_response(uri)

  html = res.body
  html.force_encoding('UTF-8')
  html.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
end

def extract_links_from_google(html)
  doc = Nokogiri::HTML(html)
  links = []

  # Selector preciso para enlaces de resultados orgánicos
  doc.css('div.yuRUbf > a').each do |a|
    href = a['href']
    if href.include?('milenio.com')
      links << href
    end
  end

  links.uniq
end

# === MAIN ===

query = 'CJNG site:milenio.com 2023'
pages = 1
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