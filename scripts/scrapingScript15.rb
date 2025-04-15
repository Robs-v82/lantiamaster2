require 'net/http'
require 'uri'
require 'nokogiri'

API_KEY = '7F4T3OWDZ2MS5CJN7RF6K7E9XVTBR0RFXXZYQD9U5C2G430S09JTMLUCKTQRUQRG3B292VW5RC6O6FUK' # ← poné tu clave real

def build_duckduckgo_url(query, offset)
  base_url = 'https://html.duckduckgo.com/html/'
  "#{base_url}?q=#{URI.encode_www_form_component(query)}&s=#{offset}"
end

def fetch_html_with_scrapingbee(url)
  uri = URI('https://app.scrapingbee.com/api/v1/')
  params = {
    api_key: API_KEY,
    url: url,
    render_js: false,
    block_resources: true
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
    # if href.include?('milenio.com')
      links << href
    # end
  end

  links.uniq
end

# === MAIN ===

# months = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre]
months = %w[enero febrero marzo abril]
year = 2025
pages_per_month = 2
all_links = []
Dir.mkdir('htmls') unless Dir.exist?('htmls')

months.each do |month|
  puts "\n📅 Procesando: #{month.capitalize} #{year}"

  pages_per_month.times do |i|
    offset = i * 30
    query = "\"Los Ardillos\" #{month} #{year}"
    url = build_duckduckgo_url(query, offset)

    puts "🔎 Página #{i + 1} — Offset #{offset}"
    html = fetch_html_with_scrapingbee(url)

    # Guardar HTML por si querés inspeccionar
    File.write("htmls/duck_cjng_#{month}_#{year}_p#{i + 1}.html", html)

    links = extract_links_from_duckduckgo(html)
    puts "   ↳ Se encontraron #{links.size} enlaces"
    all_links.concat(links)

    sleep(2)
  end
end

puts "\n✅ Total de enlaces únicos encontrados: #{all_links.uniq.size}"
puts all_links.uniq