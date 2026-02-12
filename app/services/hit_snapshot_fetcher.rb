# app/services/hit_snapshot_fetcher.rb
require "net/http"
require "uri"

class HitSnapshotFetcher
  USER_AGENT = "Mozilla/5.0 (compatible; LantiaBot/1.0)"

  def self.fix_mojibake_cp1252(s)
    return s unless s.is_a?(String)
    return s unless (s.include?("Ã") || s.include?("â€") || s.include?("Â"))
    s.encode("Windows-1252").force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")
  rescue
    s
  end

  def self.process_html(hit, body, content_type_header)
    html = body.dup.force_encoding(Encoding::BINARY)
    doc = Nokogiri::HTML(html)
    doc.search("script, style, noscript").remove

    text = doc.text.gsub(/\s+/, " ").strip
    text = text.gsub(/\{\{.*?\}\}/, "").gsub(/\s+/, " ").strip
    text = fix_mojibake_cp1252(text)
    text = text.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")

    hit.raw_html = doc.to_html
    hit.fetch_error = nil
    validate_members_presence(hit, text)
    hit.plain_text = text

    if hit.plain_text.present? && hit.plain_text.length >= 800
      hit.backup_source="html"; hit.backup_status="ok"; hit.backup_version=1
    else
      hit.backup_source="html"; hit.backup_status="partial"
    end
  end

  def self.looks_mojibake_latin1?(s)
    s.include?("Ã") || s.include?("â€") || s.include?("Â")
  end

  def self.looks_mojibake?(s)
    s.include?("��") || s.count("�") > 20
  end

  def self.call!(hit)
    return if hit.link.blank?

    uri = URI.parse(hit.link)
    res = fetch(uri)

    hit.fetch_status = res.code.to_i
    hit.fetched_at   = Time.current
    hit.final_url    = uri.to_s
    hit.fetch_error  = nil

    content_type = res["content-type"].to_s.downcase

    if content_type.include?("application/pdf")
      attach_pdf(hit, res.body)
    elsif content_type.include?("text/html")
      process_html(hit, res.body, res["content-type"])
    end
    hit.backup_checked_at = Time.current
    hit.save!
  rescue => e
    hit.backup_status = "error"
    hit.fetch_error = "#{e.class}: #{e.message}"
    hit.fetched_at  = Time.current
    hit.save!(validate: false)
  end

  private

  def self.fetch(uri, limit = 5)
    raise "Too many redirects" if limit == 0

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 20

    req = Net::HTTP::Get.new(uri.request_uri)
    req["User-Agent"] = USER_AGENT
    req["Accept"] = "*/*"

    res = http.request(req)

    if res.is_a?(Net::HTTPRedirection) && res["location"]
      new_uri = URI.parse(res["location"])
      new_uri = uri + res["location"] if new_uri.relative?
      return fetch(new_uri, limit - 1)
    end

    res
  end

  def self.attach_pdf(hit, body)
    return if hit.pdf_snapshot.attached?

    hit.pdf_snapshot.attach(
      io: StringIO.new(body),
      filename: "snapshot_hit_#{hit.id}.pdf",
      content_type: "application/pdf"
    )

    hit.backup_source  = "pdf"
    hit.backup_status  = "ok"
    hit.backup_version = 1
  end

  def self.validate_members_presence(hit, text)
    return hit.fetch_error = "NO_MEMBERS" if hit.members.empty?

    down = normalize(text)

    if down.include?("request could not be satisfied") || down.include?("access denied") || down.include?("forbidden")
      return hit.fetch_error = "FETCH_BLOCKED"
    end

    return hit.fetch_error = "TEXT_TOO_SHORT" if down.length < 800

    match = hit.members.any? do |m|
      next false if m.firstname.blank? || m.lastname1.blank?
      last_ok = down.include?(normalize(m.lastname1))
      tokens = m.firstname.split(/\s+/).map { |t| normalize(t) }.reject(&:blank?)
      name_ok = tokens.any? { |t| down.include?(t) }
      last_ok && name_ok
    end

    hit.fetch_error = "NO_MEMBER_MATCH" unless match
  end

  def self.normalize(str)
    str.to_s.downcase.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
  end

end