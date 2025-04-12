require 'net/http'
require 'uri'
require 'json'

API_KEY = '7F4T3OWDZ2MS5CJN7RF6K7E9XVTBR0RFXXZYQD9U5C2G430S09JTMLUCKTQRUQRG3B292VW5RC6O6FUK' # ← reemplaza por tu clave real

def fetch_google_results(query, start)
  base_url = 'https://app.scrapingbee.com/api/v1/'
  google_query = "CJNG site:milenio.com 2023"
  search_url = "https://www.google.com/search?q=#{URI.encode_www_form_component(google_query)}&start=#{start}"

  uri = URI(base_url)
  params = {
    api_key: API_KEY,
    url: search_url,
    google: true # ← clave para activar motor Google oficial de ScrapingBee
  }
  uri.query = URI.encode_www_form(params)

  res = Net::HTTP.get_response(uri)
  body = res.body
  body.force_encoding('UTF-8')
  body.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
end

def extract_links_from_json(json_str)
  data = JSON.parse(json_str)
  links = []

  if data['organic_results']
    data['organic_results'].each do |result|
      link = result['link']
      if link.include?('milenio.com')
        links << link
      end
    end
  end

  links.uniq
end

# === MAIN ===

pages = 5
all_links = []

(0...pages).each do |i|
  start = i * 10
  puts "\n🔍 Página #{i + 1}"

  response_json = fetch_google_results("CJNG site:milenio.com 2023", start)
  File.write("pagina_google_json_#{i + 1}.json", response_json)

  links = extract_links_from_json(response_json)
  puts "  ↳ Se encontraron #{links.size} enlaces"
  all_links.concat(links)

  sleep(2)
end

puts "\n✅ Total de links únicos encontrados: #{all_links.uniq.size}"
puts all_links.uniq