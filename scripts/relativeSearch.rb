require "ferrum"
require "cgi"

gobernador = Role.find_by(name: "Gobernador")
scope = Member.joins(:hits).distinct.where(involved: true).where.not(role: gobernador)

sites_query = [
  "site:legislacion.edomex.gob.mx",
  "site:eservicios2.aguascalientes.gob.mx",
  "site:bcs.gob.mx",
  "site:periodicooficial.col.gob.mx",
  "site:periodicooficial.campeche.gob.mx",
  "site:periodico.segobcoahuila.gob.mx",
  "site:poderjudicialchiapas.gob.mx",
  "site:stj.gob.mx"
].join(" OR ")

LIMIT = 20
START_ID = nil

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

browser = build_browser

matched_names = []
not_matched_names = []
failed_names = []

batch_scope = scope.order(:id)
batch_scope = batch_scope.where("members.id > ?", START_ID) if START_ID.present?
batch_scope = batch_scope.limit(LIMIT)

last_member_id = nil

batch_scope.each do |member|
  full_name = [
    member.firstname,
    member.lastname1,
    member.lastname2
  ].compact.map(&:to_s).map(&:strip).reject(&:blank?).join(" ")

  next if full_name.blank?

  last_member_id = member.id

  query = %("#{full_name}" #{sites_query})
  url = "https://www.google.com/search?q=#{CGI.escape(query)}"

  begin
    puts "\n[#{member.id}] Buscando: #{full_name}"
    browser.goto(url)
    sleep 5

    body_text = browser.body.to_s.gsub(/\s+/, " ").strip
    normalized_body = body_text.upcase
    normalized_name = full_name.upcase.gsub(/\s+/, " ").strip

    if normalized_body.include?("NO SE HAN ENCONTRADO RESULTADOS")
      not_matched_names << full_name
      puts "NO MATCH"
    elsif normalized_body.include?(normalized_name)
      matched_names << full_name
      puts "MATCH"
    else
      not_matched_names << full_name
      puts "NO MATCH"
    end

  rescue Ferrum::BrowserError => e
    puts "ERROR DE SESION: #{e.message}"
    failed_names << full_name

    begin
      browser.quit
    rescue
    end

    browser = build_browser
  rescue => e
    puts "ERROR GENERAL: #{e.class} - #{e.message}"
    failed_names << full_name
  end
end

begin
  browser.quit
rescue
end

puts "\n========== RESUMEN =========="
puts "Total revisados: #{matched_names.size + not_matched_names.size + failed_names.size}"
puts "Con match: #{matched_names.size}"
puts "Sin match: #{not_matched_names.size}"
puts "Con error: #{failed_names.size}"
puts "Último member.id procesado: #{last_member_id}"

puts "\nNombres con match:"
matched_names.each { |name| puts "- #{name}" }