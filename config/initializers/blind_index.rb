# config/initializers/blind_index.rb
Rails.application.config.to_prepare do
  key = Rails.application.credentials.dig(:blind_index, :master_key)
  BlindIndex.master_key = key if key.present?
end





