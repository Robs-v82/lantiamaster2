key = Rails.application.credentials.dig(:blind_index, :master_key)

# Detect rake tasks early (before Rake.application.top_level_tasks is ready)
is_assets_task = ARGV.any? { |a| a.start_with?("assets:") }

if key.present?
  BlindIndex.master_key = key
elsif is_assets_task
  # skip during assets tasks (e.g., assets:precompile)
else
  raise "BlindIndex key missing in credentials"
end



