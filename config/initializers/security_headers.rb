if Rails.env.production?
  Rails.application.config.action_dispatch.default_headers.merge!({
    'Content-Security-Policy' => 
      "default-src 'self'; " \
      "img-src 'self' data: https:; " \
      "font-src 'self' https://fonts.gstatic.com data:; " \
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com; " \
      "script-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com https://cdn.jsdelivr.net; " \
      "connect-src 'self' ws: wss:; " \
      "object-src 'none'; base-uri 'self'; frame-ancestors 'none'; " \
      "form-action 'self'; upgrade-insecure-requests"
  })
end

