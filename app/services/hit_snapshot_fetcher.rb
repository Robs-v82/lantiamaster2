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

  def self.call!(hit, require_members: true)
    return if hit.link.blank?

    pdf_before = hit.pdf_snapshot.attached?

    uri = build_http_uri(hit.link)
    unless uri
      hit.fetched_at = Time.current
      hit.backup_checked_at = Time.current
      hit.fetch_error = "INVALID_URL"

      if hit.raw_html.blank? && !hit.pdf_snapshot.attached?
        hit.backup_status = "error"
      else
        hit.backup_status = "ok"
        hit.fetch_error = nil
      end

      hit.save!(validate: false)
      return
    end

    res = fetch(uri)

    hit.fetch_status = res.code.to_i
    hit.fetched_at   = Time.current
    hit.final_url    = uri.to_s

    content_type = res["content-type"].to_s.downcase

    captured_html = false
    pdf_present   = pdf_before

    if content_type.include?("application/pdf")
      pdf_present = attach_pdf(hit, res.body)
    elsif content_type.include?("text/html")
      captured_html = capture_html_if_valid(hit, res.body, require_members: require_members)
    else
      # Leave as-is; we'll only mark an error below if we ended up with no snapshot.
    end

    hit.backup_checked_at = Time.current

    if captured_html || pdf_present
      hit.backup_status = "ok"
      hit.fetch_error = nil
    else
      hit.backup_status = "error"
      hit.fetch_error ||= "NO_SNAPSHOT"
    end

    hit.save!
  rescue => e
    hit.fetched_at  = Time.current
    hit.backup_checked_at = Time.current

    # Only mark as an error if we still have no snapshot at all.
    if hit.raw_html.blank? && !hit.pdf_snapshot.attached?
      hit.backup_status = "error"
      hit.fetch_error = "#{e.class}: #{e.message}"
    end

    hit.save!(validate: false)
  end

  private

  def self.build_http_uri(link)
    s = link.to_s.strip
    return nil if s.blank?

    escaped = URI::DEFAULT_PARSER.escape(s)
    uri = URI.parse(escaped)

    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    uri
  rescue URI::InvalidURIError
    nil
  end

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
    # If we already have a PDF snapshot, we treat that as a successful backup.
    return true if hit.pdf_snapshot.attached?

    hit.pdf_snapshot.attach(
      io: StringIO.new(body),
      filename: "snapshot_hit_#{hit.id}.pdf",
      content_type: "application/pdf"
    )

    hit.backup_source  = "pdf"
    hit.backup_status  = "ok"
    hit.backup_version = 1
    hit.fetch_error    = nil
    true
  end

  def self.capture_html_if_valid(hit, body, require_members: true)
    raw_html, text = extract_html_and_text(body)

    error_code = validation_error_for(hit, text, require_members: require_members)

    if error_code.present?
      hit.fetch_error = error_code
      return false
    end

    hit.raw_html     = raw_html
    hit.plain_text   = text
    hit.fetch_error  = nil

    hit.backup_source  = "html"
    hit.backup_status  = "ok"
    hit.backup_version = 1
    true
  end

  def self.extract_html_and_text(body)
    html = body.to_s.dup.force_encoding(Encoding::BINARY)
    doc = Nokogiri::HTML(html)
    doc.search("script, style, noscript").remove

    text = doc.text.gsub(/\s+/, " ").strip
    text = text.gsub(/\{\{.*?\}\}/, "").gsub(/\s+/, " ").strip
    text = fix_mojibake_cp1252(text)
    text = text.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")

    [doc.to_html, text]
  end

  def self.validation_error_for(hit, text, require_members: true)
    if require_members
      return "NO_MEMBERS" if hit.members.empty?
    end

    down = normalize(text)

    if down.include?("request could not be satisfied") || down.include?("access denied") || down.include?("forbidden")
      return "FETCH_BLOCKED"
    end

    return "TEXT_TOO_SHORT" if down.length < 800

    match = hit.members.any? do |m|
      next false if m.firstname.blank? || m.lastname1.blank?
      last_ok = down.include?(normalize(m.lastname1))
      tokens = m.firstname.split(/\s+/).map { |t| normalize(t) }.reject(&:blank?)
      name_ok = tokens.any? { |t| down.include?(t) }
      last_ok && name_ok
    end

    return "NO_MEMBER_MATCH" if require_members && !match

    nil
  end

  def self.normalize(str)
    str.to_s.downcase.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
  end
end