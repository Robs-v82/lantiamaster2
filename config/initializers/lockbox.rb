# config/initializers/lockbox.rb
key = Rails.application.credentials.dig(:lockbox, :master_key)

if key.present?
  Lockbox.master_key = key
elsif defined?(Rake) && Rake.application&.top_level_tasks&.any? { |t| t.start_with?("assets:") }
  # skip during assets precompile
else
  raise "Lockbox key missing in credentials"
end

