# config/initializers/lockbox.rb
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

    lb = h.dig("lockbox", "master_key").to_s
    warn "[CREDS_DEBUG] lockbox_present=#{h.key?("lockbox")} master_key_len=#{lb.length}"
  rescue => e
    warn "[CREDS_DEBUG] ERROR #{e.class}: #{e.message}"
  end
end

key = Rails.application.credentials.dig(:lockbox, :master_key)
is_assets_task = ARGV.any? { |a| a.start_with?("assets:") }

if key.present?
  Lockbox.master_key = key
elsif is_assets_task
  # skip
else
  raise "Lockbox key missing in credentials"
end



raw = Rails.application.credentials.read
h = YAML.safe_load(raw, aliases: true) || {}

key =
  h.dig("lockbox", "master_key") ||
  h.dig(:lockbox, :master_key)

is_assets_task = ARGV.any? { |a| a.start_with?("assets:") }

if key.present?
  Lockbox.master_key = key
elsif is_assets_task
  # skip during assets tasks
else
  raise "Lockbox key missing in credentials"
end


