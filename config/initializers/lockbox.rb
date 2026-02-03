key = Rails.application.credentials.dig(:lockbox, :master_key)
raise "Lockbox key missing in credentials" if key.blank?
Lockbox.master_key = key
