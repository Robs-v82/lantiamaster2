# frozen_string_literal: true

require 'cgi'
require 'csv'
require 'net/http'
require 'nokogiri'
require 'set'
require 'uri'

SCRAPINGBEE_API_KEY ||= ENV['SCRAPINGBEE_API_KEY']

raise 'Falta SCRAPINGBEE_API_KEY' if SCRAPINGBEE_API_KEY.to_s.strip.empty?

OUTPUT_CSV = 'daily_search_links.csv'
REQUEST_TIMEOUT = 45
MAX_RESULTS_PER_QUERY = 5
REQUIRED_TERM = 'sonora'

ALLOWED_NEWS_DOMAINS = [
  "infocajeme.com",
  "jornada.com.mx",
  "infobae.com",
  "proceso.com.mx",
  "milenio.com",
  "eluniversal.com.mx",
  "reforma.com",
  "eleconomista.com.mx",
  "elfinanciero.com.mx",
  "excelsior.com.mx",
  "zetatijuana.com",
  "sinembargo.mx",
  "lasillarota.com",
  "oem.com.mx",
  "informador.mx",
  "noroeste.com.mx",
  "gob.mx",
  "elnorte.com",
  "elsiglodetorreon.com.mx",
  "animalpolitico.com",
  "wradio.com.mx"
].freeze

DEFAULT_ORGANIZATIONS = [
  'cartel',
  'Arellano Félix',
  'Beltrán Leyva',
  'Arellano Félix',
  'Los Salazar',
  'Cártel de Caborca',
  'Los Rusos',
  'Los Deltas',
  'Los Paredes',
  'Los Cazadores',
  'CJNG',
  'Cártel de Sinaloa',
  'Chapitos',
  'Mayiza',
  'huachicol',
  'cobro de cuota'
].freeze

KEYWORDS = [
  'empresario',
  'detenido',
  'capturado',
  'operador',
  'líder',
  'jefe de plaza',
  'prestanombres',
  'lavado de dinero',
  'vínculos',
  'nexos',
  'alcalde',
  'regidor',
  'director de seguridad',
  'policía',
  'fiscal',
  'tesorero',
  'gobernador',
  'diputado'
].freeze

def build_queries(organization_name)
  KEYWORDS.map { |keyword| %("#{organization_name}" "#{keyword}" "#{REQUIRED_TERM}") }
end

def duckduckgo_url(query)
  encoded_query = CGI.escape(query)
  "https://html.duckduckgo.com/html/?q=#{encoded_query}&df=m"
end

def scrapingbee_get(target_url)
  uri = URI('https://app.scrapingbee.com/api/v1/')
  uri.query = URI.encode_www_form(
    api_key: SCRAPINGBEE_API_KEY,
    url: target_url,
    render_js: 'false'
  )

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = REQUEST_TIMEOUT
  http.open_timeout = REQUEST_TIMEOUT

  request = Net::HTTP::Get.new(uri)
  response = http.request(request)

  unless response.is_a?(Net::HTTPSuccess)
    raise "Error HTTP #{response.code} al pedir #{target_url}: #{response.body}"
  end

  response.body
end

def normalize_url(url)
  return nil if url.to_s.strip.empty?

  if url.include?("duckduckgo.com/l/?")
    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query || "").to_h
    return CGI.unescape(params["uddg"]) if params["uddg"]
  end

  uri = URI.parse(url)
  uri.fragment = nil
  uri.to_s
rescue
  nil
end

def allowed_news_domain?(url)
  uri = URI.parse(url)
  host = uri.host.to_s.downcase
  return false if host.empty?

  ALLOWED_NEWS_DOMAINS.any? do |allowed_domain|
    host == allowed_domain || host.end_with?(".#{allowed_domain}")
  end
rescue
  false
end

def parse_duckduckgo_results(html)
  doc = Nokogiri::HTML(html)
  results = []

  doc.css('.result').each do |node|
    link_node = node.at_css('.result__title a') || node.at_css('a.result__a')
    next unless link_node

    title = link_node.text.to_s.strip
    href = link_node['href'].to_s.strip
    next if title.empty? || href.empty?

    clean_url = normalize_url(href)
    next unless clean_url
    next unless allowed_news_domain?(clean_url)

    results << {
      title: title,
      source_url: clean_url
    }
  end

  results.uniq { |r| r[:source_url] }.first(MAX_RESULTS_PER_QUERY)
end

def search_results_for_query(query)
  html = scrapingbee_get(duckduckgo_url(query))
  parse_duckduckgo_results(html)
end

def export_csv(rows)
  CSV.open(OUTPUT_CSV, 'w', write_headers: true, headers: %w[organization_name keyword query title source_url]) do |csv|
    rows.each do |row|
      csv << [
        row[:organization_name],
        row[:keyword],
        row[:query],
        row[:title],
        row[:source_url]
      ]
    end
  end
end

organizations = ARGV.empty? ? DEFAULT_ORGANIZATIONS : ARGV
rows = []
seen_pairs = Set.new

organizations.each do |organization_name|
  puts "Buscando: #{organization_name}"

  build_queries(organization_name).each do |query|
    keyword = query.scan(/"([^"]+)"/).flatten[1]

    begin
      results = search_results_for_query(query)

      results.each do |result|
        pair_key = [result[:source_url], keyword]
        next if seen_pairs.include?(pair_key)
        seen_pairs << pair_key

        rows << {
          organization_name: organization_name,
          keyword: keyword,
          query: query,
          title: result[:title],
          source_url: result[:source_url]
        }
      end
    rescue => e
      warn "Falló query #{query}: #{e.message}"
    end
  end
end

export_csv(rows)
puts "Listo: #{rows.size} links guardados en #{OUTPUT_CSV}"
puts "\nLinks encontrados:\n\n"

rows
  .group_by { |r| r[:source_url] }
  .sort_by { |link, _group| link }
  .each do |link, group|
    keywords = group.map { |r| r[:keyword] }.uniq.sort
    puts "#{link} | palabras clave: #{keywords.join(', ')}"
  end
