# frozen_string_literal: true

require 'cgi'
require 'csv'
require 'net/http'
require 'nokogiri'
require 'set'
require 'uri'

SCRAPINGBEE_API_KEY ||= ENV['SCRAPINGBEE_API_KEY']
raise 'Falta SCRAPINGBEE_API_KEY' if SCRAPINGBEE_API_KEY.to_s.strip.empty?

REQUEST_TIMEOUT = 45
MAX_RESULTS_PER_QUERY = 10
OUTPUT_CSV = 'member_official_publications_links.csv'

ALLOWED_DOMAINS = [
  'legislacion.edomex.gob.mx',
  'eservicios2.aguascalientes.gob.mx',
  'bcs.gob.mx',
  'periodicooficial.col.gob.mx',
  'periodicooficial.campeche.gob.mx',
  'periodico.segobcoahuila.gob.mx',
  'poderjudicialchiapas.gob.mx',
  'stj.gob.mx'
].freeze

# ============================================================
# Si estos métodos ya existen en tu aplicación y son accesibles
# desde rails runner, puedes borrar este módulo y ajustar
# HomoScoreHelper.<metodo> por tus llamadas reales.
# ============================================================
module HomoScoreHelper
  module_function

  def normalize(text)
    return nil if text.blank?

    text.to_s
        .unicode_normalize(:nfkd)
        .encode('ASCII', replace: '')
        .downcase
        .gsub(/[^a-z0-9\s]/, ' ')
        .gsub(/\s+/, ' ')
        .strip
  end

  def pick_best_key(keys, norm)
    return norm if keys.include?(norm)

    contained = keys.select { |k| norm.include?(k) }
    return contained.max_by(&:length) if contained.any?

    containing = keys.select { |k| k.include?(norm) }
    containing.max_by(&:length)
  end

  def token_freq(names_norm, keys, token_norm)
    best = pick_best_key(keys, token_norm)
    best ? names_norm[best] : 5
  end

  def compound_freq(names_norm, keys, raw)
    norm = normalize(raw)
    parts = norm.split(/\s+/).reject(&:blank?)
    return token_freq(names_norm, keys, norm) if parts.length <= 1

    part_freqs = parts.map { |p| token_freq(names_norm, keys, p) }
    maxf = part_freqs.max || 5
    avgf = part_freqs.sum.to_f / part_freqs.length

    bonus = [0.10 * (parts.length - 1), 0.30].min
    ([avgf, maxf].max * (1.0 + bonus)).round
  end

  # En modo name: exact match manda. Inclusion solo como fallback y con descuento.
  def token_freq_strict(names_norm, keys, token_norm)
    return 5 if token_norm.blank?

    # exact
    return names_norm[token_norm] if names_norm.key?(token_norm)

    # fallback por inclusion (pero penalizado)
    contained = keys.select { |k| token_norm.include?(k) }
    best = if contained.any?
      contained.max_by(&:length)
    else
      containing = keys.select { |k| k.include?(token_norm) }
      containing.max_by(&:length)
    end

    base = best ? names_norm[best] : 5
    # Penaliza fuerte porque no fue exacto (ajusta 0.25 a 0.10–0.40 según gusto)
    (base * 0.25).round
  end

  # Sustituye este método por tu implementación real si ya existe
  def compute_name_score(full_name)
    names_norm = Name.all.pluck(:word, :freq).to_h { |w, f| [normalize(w), f.to_i] }
    keys = names_norm.keys

    tokens = normalize(full_name).split(/\s+/).reject(&:blank?)
    return nil if tokens.empty?

    freqs = tokens.map { |t| token_freq_strict(names_norm, keys, t) }.sort.reverse

    top3 = freqs.first(3)
    top3 << 5 while top3.length < 3

    base = ((top3[0] * top3[1] * top3[2]) / 10000.0).round

    # Penalización por tokens extra (4+)
    extras = [tokens.length - 3, 0].max
    penalty = (0.60 ** extras)

    (base * penalty).round
  end

  # Sustituye este método por tu implementación real si ya existe
  def compute_homo_score(firstname, lastname1, lastname2)
    # Index normalizado: "jose" => 175, etc. (acentos/capitalización ya no importan)
    names_norm = Name.all.pluck(:word, :freq).to_h do |w, f|
      [normalize(w), f.to_i]
    end
    keys = names_norm.keys

    # Helper local: exact > contained > containing
    pick_best = lambda do |norm|
      if keys.include?(norm)
        norm
      else
        contained = keys.select { |k| norm.include?(k) }
        if contained.any?
          contained.max_by(&:length)
        else
          containing = keys.select { |k| k.include?(norm) }
          containing.max_by(&:length)
        end
      end
    end

    freqs = [firstname, lastname1, lastname2].map do |val|
      norm = normalize(val)
      parts = norm.split(/\s+/).reject(&:blank?)

      if parts.length > 1
        part_freqs = parts.map do |p|
          pbest = pick_best.call(p)
          pbest ? names_norm[pbest] : 5
        end

        maxf = part_freqs.max || 5
        avgf = (part_freqs.sum.to_f / part_freqs.length)

        # bono pequeño por compuesto (10%), capado a +30% aunque haya 3+ partes
        bonus = [0.10 * (parts.length - 1), 0.30].min
        ( [avgf, maxf].max * (1.0 + bonus) ).round
      else
        best = pick_best.call(norm)
        best ? names_norm[best] : 5
      end

    end

    ((freqs[0] * freqs[1] * freqs[2]) / 10000.0).round
  end

  def member_homo_score(member)
    qp = {
      name: member.try(:fullname),
      firstname: member.try(:firstname),
      lastname1: member.try(:lastname1),
      lastname2: member.try(:lastname2)
    }

    if qp[:name].present?
      compute_name_score(qp[:name])
    else
      compute_homo_score(qp[:firstname], qp[:lastname1], qp[:lastname2])
    end
  end

  def normalized_inputs(member)
    qp = {
      name: member.try(:fullname),
      firstname: member.try(:firstname),
      lastname1: member.try(:lastname1),
      lastname2: member.try(:lastname2)
    }

    input_name = qp[:name].present? ? normalize(qp[:name]) : nil
    input_firstname = qp[:name].present? ? nil : normalize(qp[:firstname])
    input_lastname1 = qp[:name].present? ? nil : normalize(qp[:lastname1])
    input_lastname2 = qp[:name].present? ? nil : normalize(qp[:lastname2])

    {
      input_name: input_name,
      input_firstname: input_firstname,
      input_lastname1: input_lastname1,
      input_lastname2: input_lastname2
    }
  end
end

def google_url(query)
  encoded_query = CGI.escape(query)
  "https://www.google.com/search?q=#{encoded_query}&num=#{MAX_RESULTS_PER_QUERY}"
end

def scrapingbee_get(target_url)
  uri = URI('https://app.scrapingbee.com/api/v1/')
  uri.query = URI.encode_www_form(
    api_key: SCRAPINGBEE_API_KEY,
    url: target_url,
    custom_google: 'true',
    render_js: 'true',
    block_resources: 'false',
    premium_proxy: 'true'
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

  body = response.body
  body = body.force_encoding('UTF-8')
  body = body.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  body
end



def normalize_url(url)
  return nil if url.to_s.strip.empty?

  if url.start_with?('/url?')
    uri = URI.parse("https://www.google.com#{url}")
    params = URI.decode_www_form(uri.query || '').to_h
    return CGI.unescape(params['q']) if params['q'].present?
  end

  uri = URI.parse(url)
  uri.fragment = nil
  uri.to_s
rescue
  nil
end

def allowed_domain?(url)
  uri = URI.parse(url)
  host = uri.host.to_s.downcase
  return false if host.empty?

  ALLOWED_DOMAINS.any? do |allowed_domain|
    host == allowed_domain || host.end_with?(".#{allowed_domain}")
  end
rescue
  false
end

def parse_google_results(html)
  doc = Nokogiri::HTML(html, nil, 'UTF-8')
  results = []

  doc.css('a').each do |link_node|
    href = link_node['href'].to_s.strip
    next if href.empty?
    next unless href.start_with?('/url?') || href.start_with?('http')

    clean_url = normalize_url(href)
    next unless clean_url
    next unless allowed_domain?(clean_url)

    title = link_node.text.to_s.strip
    next if title.empty?

    results << {
      title: title,
      source_url: clean_url
    }
  end

  results.uniq { |r| r[:source_url] }.first(MAX_RESULTS_PER_QUERY)
end

def build_queries_for_member(fullname)
  ALLOWED_DOMAINS.map do |domain|
    %("#{fullname}" site:#{domain})
  end
end

def search_results_for_query(query)
  html = scrapingbee_get(google_url(query))

  domain = query[/site:([^\s]+)/, 1]
  puts "include dominio? #{html.include?(domain)}"
  puts "include q=? #{html.include?('/url?q=')}"

  if domain && html.include?(domain)
    idx = html.index(domain)
    start_pos = [idx - 500, 0].max
    end_pos = [idx + 1500, html.length - 1].min

    puts "\n--- FRAGMENTO ---"
    puts html[start_pos..end_pos]
    puts "--- FIN FRAGMENTO ---\n"
  end

  []
end

def export_csv(rows)
  CSV.open(
    OUTPUT_CSV,
    'w',
    write_headers: true,
    headers: %w[
      member_id
      fullname
      homo_score
      query
      title
      source_url
    ]
  ) do |csv|
    rows.each do |row|
      csv << [
        row[:member_id],
        row[:fullname],
        row[:homo_score],
        row[:query],
        row[:title],
        row[:source_url]
      ]
    end
  end
end

rows = []
seen_pairs = Set.new
matches_by_member = Hash.new { |h, k| h[k] = [] }


  scope = ["Juan Carlos Pérez Hernández"]
# scope = Member
#   .joins(:hits)
#   .distinct
#   .where(involved:true)
#   .where.not(
#     id: MemberRelationship.select(:member_a_id)
#   ).where.not(
#     id: MemberRelationship.select(:member_b_id)
#   )
# Si quieres limitar para prueba:
# scope = Member.where(id: 1..100)

scope.each do |member|
# scope.find_each(batch_size: 100) do |member|
  
  fullname = member
  # fullname = member.try(:fullname).to_s.strip
  next if fullname.blank?

  # homo_score = HomoScoreHelper.member_homo_score(member)

  # next unless homo_score < 2

  normalized = HomoScoreHelper.normalized_inputs(member)
  puts "\nEvaluando member: #{fullname}"
  # puts "  homo_score: #{homo_score}"
  # puts "  input_name: #{normalized[:input_name]}" if normalized[:input_name].present?

  build_queries_for_member(fullname).each do |query|
    begin
      results = search_results_for_query(query)

      results.each do |result|
        pair_key = "#{member.id}::#{result[:source_url]}"
        next if seen_pairs.include?(pair_key)

        seen_pairs << pair_key

        row = {
          member_id: member.id,
          fullname: fullname,
          homo_score: homo_score,
          query: query,
          title: result[:title],
          source_url: result[:source_url]
        }

        rows << row
        matches_by_member[member.id] << row
      end
    rescue => e
      warn "Falló query para #{fullname} | #{query}: #{e.message}"
    end
  end
end

export_csv(rows)

puts "\nListo: #{rows.size} links guardados en #{OUTPUT_CSV}"
puts "\nCoincidencias encontradas:\n\n"

matches_by_member.each_value do |member_rows|
  next if member_rows.empty?

  fullname = member_rows.first[:fullname]
  puts fullname

  member_rows
    .map { |r| r[:source_url] }
    .uniq
    .sort
    .each do |link|
      puts "  - #{link}"
    end

  puts
end
