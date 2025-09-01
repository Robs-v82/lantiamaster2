Rails.application.config.session_store :cookie_store,
  key: '_lantia_dash',
  secure: Rails.env.production?,   # <- solo exige Secure en prod
  httponly: true,
  same_site: :lax
