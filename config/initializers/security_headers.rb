# CSP básica para subir nota en Mozilla Observatory sin romper la app
Rails.application.config.action_dispatch.default_headers.merge!({
  'Content-Security-Policy' =>
    "default-src 'self'; " \
    "img-src 'self' data: https:; " \
    "object-src 'none'; " \
    "base-uri 'self'; " \
    "frame-ancestors 'none'; " \
    "form-action 'self'; " \
    "upgrade-insecure-requests"
})
