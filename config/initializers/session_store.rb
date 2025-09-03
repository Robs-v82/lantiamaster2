Rails.application.config.session_store :cookie_store,
  key: '_lantia_dash',
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax,
  expire_after: 60.minutes
