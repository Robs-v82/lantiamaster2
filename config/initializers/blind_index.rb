# config/initializers/blind_index.rb
key = Rails.application.credentials.dig(:blind_index, :master_key)

# Assets precompile loads the app but doesn't need BlindIndex.
# Avoid failing deploys during assets:precompile.
if key.present?
  BlindIndex.master_key = key
elsif defined?(Rake) && Rake.application&.top_level_tasks&.any? { |t| t.start_with?("assets:") }
  # skip
else
  raise "BlindIndex key missing in credentials"
end


