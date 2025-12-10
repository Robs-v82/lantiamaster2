# script/memberLinkSearch.rb
# Uso sugerido:
#   rails runner script/memberLinkSearch.rb
#
# Requiere:
#   - GEM 'nokogiri'
#   - SCRAPINGBEE_API_KEY definido en variables de entorno
#
# IMPORTANTE: revisar siempre las condiciones de uso de Google antes de automatizar consultas.

require_relative "../config/environment"
require "net/http"
require "uri"
require "nokogiri"

class MemberLinkSearch
  SCRAPINGBEE_ENDPOINT = "https://app.scrapingbee.com/api/v1".freeze

  API_KEY="7F4T3OWDZ2MS5CJN7RF6K7E9XVTBR0RFXXZYQD9U5C2G430S09JTMLUCKTQRUQRG3B292VW5RC6O6FUK"

  def initialize(members, api_key: ENV["SCRAPINGBEE_API_KEY"])
    @members = members
    @api_key = API_KEY
  end

  def run
    @members.find_each do |member|
      links = search_for_member(member)
      print_member_results(member, links)
    end
  end

  private

  def search_for_member(member)
    fullname = member.fullname
    return [] if fullname.blank?

    queries = [
      %Q{("#{fullname}") site:legislacion.edomex.gob.mx},
      %Q{("#{fullname}") AROUND(5) hermano}
    ]

    all_links = []

    queries.each do |query|
      html = fetch_google_html(query)
      query_links = extract_links(html).first(5)
      all_links.concat(query_links)
    end

    all_links.uniq
  end

  # Llama a Google a través de ScrapingBee
  def fetch_google_html(query)
    google_url = "https://www.google.com/search?" + URI.encode_www_form(
      q:  query,
      num: 10,
      hl: "es"
    )

    uri = URI(SCRAPINGBEE_ENDPOINT)
    uri.query = URI.encode_www_form(
      api_key:   @api_key,
      url:       google_url,
      render_js: false # html estático es suficiente para resultados básicos
    )

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      warn "Error HTTP #{response.code} para query: #{query}"
      return ""
    end

    response.body
  rescue => e
    warn "Error al pedir resultados para #{query}: #{e.class} - #{e.message}"
    ""
  end

  # Extrae links orgánicos de la página de resultados de Google
  def extract_links(html)
    return [] if html.to_s.strip.empty?

    doc = Nokogiri::HTML(html)
    links = []

    # Estructura típica de resultados orgánicos (puede cambiar con el tiempo)
    # 1) Selección moderna: div.yuRUbf > a
    doc.css("div.yuRUbf > a").each do |a|
      href = a["href"]
      next if href.nil? || href.empty?
      next if href.start_with?("/search?") # descartar navegación interna de Google
      links << href
    end

    # 2) Fallback genérico para otros layouts
    if links.empty?
      doc.css("div.g a").each do |a|
        href = a["href"]
        next if href.nil? || href.empty?
        next if href.start_with?("/search?")
        links << href
      end
    end

    links.uniq
  end

  def print_member_results(member, links)
    puts "Member ##{member.id} – #{member.fullname}"

    if links.empty?
      puts "  Sin resultados"
    else
      links.each_with_index do |link, idx|
        puts "  [#{idx + 1}] #{link}"
      end
    end

    puts "-" * 60
  end
end

# ─────────────────────────────────────────────────────────
# Aquí defines myMembers. Puedes ajustar libremente.
# Ejemplos:
#
# myMembers = Member.with_more_than_hits(5)
# myMembers = Member.where(id: [1, 2, 3])
# myMembers = Member.where("created_at >= ?", 1.year.ago)
#
# Como pediste que myMembers se definirá más adelante, lo dejo como ejemplo:
myMembers = Member.where(firstname: "Salvador", lastname1: "Cienfuegos")
# myMembers = Member.with_more_than_hits(4).where.not(id: MemberRelationship.select(:member_a_id)).where.not(id: MemberRelationship.select(:member_b_id))

MemberLinkSearch.new(myMembers).run