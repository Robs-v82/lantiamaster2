# config/initializers/blind_index.rb
require "yaml"

if ENV["CREDS_DEBUG"] == "1"
  begin
    warn "[CREDS_DEBUG] ARGV=#{ARGV.inspect}"
    c = Rails.application.credentials
    warn "[CREDS_DEBUG] content_path=#{c.content_path}"
    warn "[CREDS_DEBUG] key_path=#{c.key_path}"

    raw = c.read
    warn "[CREDS_DEBUG] read_bytes=#{raw.bytesize} read_lines=#{raw.lines.count}"

    require "yaml"
    h = YAML.safe_load(raw, aliases: true) || {}
    warn "[CREDS_DEBUG] yaml_top_keys=#{h.keys.map(&:to_s).sort.join(",")}"

    bi = h.dig("blind_index", "master_key").to_s
    warn "[CREDS_DEBUG] blind_index_present=#{h.key?("blind_index")} master_key_len=#{bi.length}"
  rescue => e
    warn "[CREDS_DEBUG] ERROR #{e.class}: #{e.message}"
  end
end

key = Rails.application.credentials.dig(:blind_index, :master_key)
is_assets_task = ARGV.any? { |a| a.start_with?("assets:") }

if key.present?
  BlindIndex.master_key = key
elsif is_assets_task
  # skip
else
  raise "BlindIndex key missing in credentials"
end

raw = Rails.application.credentials.read
h = YAML.safe_load(raw, aliases: true) || {}

key =
  h.dig("blind_index", "master_key") ||
  h.dig(:blind_index, :master_key)

is_assets_task = ARGV.any? { |a| a.start_with?("assets:") }

if key.present?
  BlindIndex.master_key = key
elsif is_assets_task
  # skip during assets tasks
else
  raise "BlindIndex key missing in credentials"
end




