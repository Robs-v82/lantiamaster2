# frozen_string_literal: true

require 'cgi'
require 'csv'
require 'net/http'
require 'nokogiri'
require 'set'
require 'uri'

SCRAPINGBEE_API_KEY ||= ENV['SCRAPINGBEE_API_KEY']

raise 'Falta SCRAPINGBEE_API_KEY' if SCRAPINGBEE_API_KEY.to_s.strip.empty?

OUTPUT_CSV = 'congress_search_links.csv'
REQUEST_TIMEOUT = 45
MAX_RESULTS_PER_QUERY = 5

DEFAULT_ORGANIZATIONS = [
  'cartel',
  'Cártel Jalisco',
  'CJNG',
  'Cártel de Sinaloa',
  'Mayiza',
  'Chapitos',
  'Guano',
  'Fuerzas Especiales',
  'Los Cazadores',
  'Los Chimales',
  'Los Güeritos',
  'Mayo Zambada',
  'laboratorio',
  'narco',
].freeze

def congress_members
  organization = Organization.find_by(name: 'Congreso de Sinaloa')
  raise 'No se encontró la organización: Congreso de Sinaloa' unless organization
  from = "2024-10-01"
  to = "2027-10-01"
  Member.joins(:appointments)
        .where(appointments: { organization_id: organization.id, period: from...to })
        .distinct
end

def build_queries(member_fullname)
  DEFAULT_ORGANIZATIONS.map do |term|
    {
      member_name: member_fullname,
      organization_term: term,
      query: %("#{member_fullname}" "#{term}")
    }
  end
end

def duckduckgo_url(query)
  encoded_query = CGI.escape(query)
  "https://html.duckduckgo.com/html/?q=#{encoded_query}"
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

  if url.include?('duckduckgo.com/l/?')
    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query || '').to_h
    return CGI.unescape(params['uddg']) if params['uddg']
  end

  uri = URI.parse(url)
  uri.fragment = nil
  uri.to_s
rescue StandardError
  nil
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
  CSV.open(
    OUTPUT_CSV,
    'w',
    write_headers: true,
    headers: %w[member_id member_name organization_term query title source_url]
  ) do |csv|
    rows.each do |row|
      csv << [
        row[:member_id],
        row[:member_name],
        row[:organization_term],
        row[:query],
        row[:title],
        row[:source_url]
      ]
    end
  end
end

rows = []
seen_pairs = Set.new

congress_members.find_each do |member|
  member_name = member.fullname.to_s.strip
  next if member_name.empty?

  puts "Buscando coincidencias para: #{member_name}"

  build_queries(member_name).each do |query_data|
    begin
      results = search_results_for_query(query_data[:query])

      results.each do |result|
        unique_key = [member.id, result[:source_url]]
        next if seen_pairs.include?(unique_key)

        seen_pairs << unique_key

        rows << {
          member_id: member.id,
          member_name: query_data[:member_name],
          organization_term: query_data[:organization_term],
          query: query_data[:query],
          title: result[:title],
          source_url: result[:source_url]
        }
      end
    rescue StandardError => e
      warn "Falló query #{query_data[:query]}: #{e.message}"
    end
  end
end

export_csv(rows)

puts "Listo: #{rows.size} links guardados en #{OUTPUT_CSV}"
puts "\nLinks encontrados:\n\n"

rows
  .map { |r| [r[:member_name], r[:organization_term], r[:source_url]] }
  .uniq
  .sort_by { |member_name, term, url| [member_name, term, url] }
  .each do |member_name, term, link|
    puts "[#{member_name}] [#{term}] #{link}"
  end
