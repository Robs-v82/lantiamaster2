# config/initializers/lockbox.rb
Rails.application.config.to_prepare do
  key = Rails.application.credentials.dig(:lockbox, :master_key)
  Lockbox.master_key = key if key.present?
end


