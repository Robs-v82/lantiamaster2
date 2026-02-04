key = Rails.application.credentials.dig(:lockbox, :master_key)
is_assets_task = ARGV.any? { |a| a.start_with?("assets:") }

if key.present?
  Lockbox.master_key = key
elsif is_assets_task
  # skip during assets tasks
else
  raise "Lockbox key missing in credentials"
end


