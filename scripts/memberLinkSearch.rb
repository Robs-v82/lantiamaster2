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
require "json"   # 👈 importante

class MemberLinkSearch
  SCRAPINGBEE_ENDPOINT = "https://app.scrapingbee.com/api/v1".freeze
  GOOGLE_ENDPOINT = "https://app.scrapingbee.com/api/v1/store/google".freeze
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
      query_links = fetch_google_links(query).first(5)
      all_links.concat(query_links)
    end

    all_links.uniq
  end

  # Llama a Google a través de ScrapingBee
  def fetch_google_links(query)
    uri = URI(GOOGLE_ENDPOINT)
    uri.query = URI.encode_www_form(
      api_key: API_KEY,
      search:  query,
      language: "es",       # resultados en español
      extra_params: "num=10" # como el ?num=10 de Google
      # light_request: false # opcional: más completo, pero más caro
    )

    puts "\n[DEBUG] Google API query:"
    puts "       #{query}"

    response = Net::HTTP.get_response(uri)
    puts "[DEBUG] HTTP status: #{response.code}"

    unless response.is_a?(Net::HTTPSuccess)
      warn "[DEBUG] Respuesta NO exitosa: #{response.body[0..200]}"
      return []
    end

    data = JSON.parse(response.body) rescue nil
    unless data && data["organic_results"].is_a?(Array)
      warn "[DEBUG] Sin organic_results en respuesta"
      return []
    end

    data["organic_results"].map { |r| r["url"] }.compact.uniq
  rescue => e
    warn "Error al pedir resultados para #{query}: #{e.class} - #{e.message}"
    []
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
# myMembers = Member.where(firstname: "Salvador", lastname1: "Cienfuegos")
myMembers = Member.with_more_than_hits(4).where.not(id: MemberRelationship.select(:member_a_id)).where.not(id: MemberRelationship.select(:member_b_id))

MemberLinkSearch.new(myMembers).run