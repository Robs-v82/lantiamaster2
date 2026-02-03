key = Rails.application.credentials.dig(:blind_index, :master_key)
raise "BlindIndex key missing in credentials" if key.blank?
BlindIndex.master_key = key

