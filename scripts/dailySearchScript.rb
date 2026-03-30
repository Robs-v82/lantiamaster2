# frozen_string_literal: true

require "cgi"
require "csv"
require "nokogiri"
require "set"
require "uri"
require "ferrum"

OUTPUT_CSV = "daily_search_links.csv"
MAX_RESULTS_PER_QUERY = 5
SEARCH_ENGINE = "google" # opciones: "google" o "duckduckgo"
KEYWORD_COMBINATION_LIMIT = 3

ALLOWED_NEWS_DOMAINS = [
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
  "wradio.com.mx",
  "reporteindigo.com"
].freeze

DEFAULT_ORGANIZATIONS = [
  "cartel",
  "Cártel Jalisco",
  "Cártel de Sinaloa",
  "Mayiza",
  "Chapitos",
  "CJNG",
  "Cárteles Unidos",
  "Cártel del Noreste",
  "Familia Michoacana",
  "huachicol",
  "cobro de cuota"
].freeze

KEYWORDS = [
  "empresario",
  "detenido",
  "operador",
  "líder",
  "prestanombres",
  "vínculos",
  "alcalde",
  "funcionario",
  "gobernador",
].freeze

def build_browser
  Ferrum::Browser.new(
    headless: false,
    timeout: 30,
    process_timeout: 20,
    browser_options: {
      "no-sandbox" => nil,
      "disable-dev-shm-usage" => nil
    }
  )
end

def build_queries(organization_name, use_keywords: true)
  if use_keywords
    KEYWORDS.map do |keyword|
      {
        keyword: keyword,
        query: %("#{organization_name}" "#{keyword}")
      }
    end
  else
    [
      {
        keyword: nil,
        query: %("#{organization_name}")
      }
    ]
  end
end

def google_url(query)
  "https://www.google.com/search?q=#{CGI.escape(query)}&num=10&hl=es&tbs=qdr:d"
end

def duckduckgo_url(query)
  "https://duckduckgo.com/html/?q=#{CGI.escape(query)}&df=d"
end

def normalize_url(url)
  return nil if url.to_s.strip.empty?

  parsed = URI.parse(url)

  if parsed.host.to_s.include?("google.") && parsed.path == "/url"
    params = URI.decode_www_form(parsed.query.to_s).to_h
    return normalize_url(params["q"]) if params["q"]
  end

  if url.include?("duckduckgo.com/l/?")
    params = URI.decode_www_form(parsed.query.to_s).to_h
    return normalize_url(CGI.unescape(params["uddg"])) if params["uddg"]
  end

  parsed.fragment = nil
  parsed.to_s
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

def result_title_from_anchor(anchor)
  text = anchor.text.to_s.gsub(/\s+/, " ").strip
  return nil if text.empty?

  text
end

def parse_google_results(html)
  doc = Nokogiri::HTML(html)
  results = []

  doc.css("a").each do |a|
    href = a["href"].to_s.strip
    next if href.empty?
    next unless href.start_with?("/url?q=")

    clean_url = normalize_url("https://www.google.com#{href}")
    next unless clean_url
    next unless allowed_news_domain?(clean_url)

    title = result_title_from_anchor(a)
    next if title.to_s.strip.empty?

    results << {
      title: title,
      source_url: clean_url
    }
  end

  results
    .uniq { |r| r[:source_url] }
    .first(MAX_RESULTS_PER_QUERY)
end

def parse_duckduckgo_results(html)
  doc = Nokogiri::HTML(html)
  results = []

  doc.css(".result").each do |node|
    link_node = node.at_css(".result__title a") || node.at_css("a.result__a")
    next unless link_node

    title = link_node.text.to_s.strip
    href = link_node["href"].to_s.strip
    next if title.empty? || href.empty?

    clean_url = normalize_url(href)
    next unless clean_url
    next unless allowed_news_domain?(clean_url)

    results << {
      title: title,
      source_url: clean_url
    }
  end

  results
    .uniq { |r| r[:source_url] }
    .first(MAX_RESULTS_PER_QUERY)
end

def search_url_for(query)
  SEARCH_ENGINE == "duckduckgo" ? duckduckgo_url(query) : google_url(query)
end

def parse_results(html)
  SEARCH_ENGINE == "duckduckgo" ? parse_duckduckgo_results(html) : parse_google_results(html)
end

def maybe_accept_google_consent(browser)
  body = browser.body.to_s

  return unless body.include?("Antes de ir a Google") || body.include?("Before you continue to Google")

  buttons = browser.css("button")
  target = buttons.find do |btn|
    txt = btn.text.to_s.strip.downcase
    txt.include?("acepto") ||
      txt.include?("accept all") ||
      txt.include?("i agree") ||
      txt.include?("rechazar") == false && txt.include?("aceptar")
  end

  target&.click
  sleep 2
rescue
  nil
end

def search_results_for_query(browser, query)
  url = search_url_for(query)

  browser.goto(url)
  sleep(rand(10..13))

  maybe_accept_google_consent(browser) if SEARCH_ENGINE == "google"

  html = browser.body.to_s
  parse_results(html)
end

def export_csv(rows)
  CSV.open(OUTPUT_CSV, "w", write_headers: true, headers: %w[organization_name keyword query title source_url]) do |csv|
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

browser = build_browser
rows = []
seen_urls = Set.new

organizations.each_with_index do |organization_name, index|
  use_keywords = index < KEYWORD_COMBINATION_LIMIT
  queries = build_queries(organization_name, use_keywords: use_keywords)

  puts "Buscando: #{organization_name}"

  queries.each do |query_data|
    query = query_data[:query]
    keyword = query_data[:keyword]

    begin
      results = search_results_for_query(browser, query)

      results.each do |result|
        next if seen_urls.include?(result[:source_url])

        seen_urls << result[:source_url]

        rows << {
          organization_name: organization_name,
          keyword: keyword,
          query: query,
          title: result[:title],
          source_url: result[:source_url]
        }
      end

      sleep(rand(4..9))
    rescue Ferrum::BrowserError => e
      warn "ERROR DE SESION en query #{query}: #{e.message}"

      begin
        browser.quit
      rescue
      end

      browser = build_browser
    rescue => e
      warn "Falló query #{query}: #{e.class} - #{e.message}"
    end
  end
end

begin
  browser.quit
rescue
end

export_csv(rows)
puts "Listo: #{rows.size} links guardados en #{OUTPUT_CSV}"
puts "\nLinks encontrados:\n\n"

rows
  .map { |r| r[:source_url] }
  .uniq
  .sort
  .each do |link|
    puts link
  end
