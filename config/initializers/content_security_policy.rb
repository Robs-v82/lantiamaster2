Rails.application.config.content_security_policy do |policy|
  # Scripts externos permitidos (coincidir con lo que uses)
  policy.script_src :self,
                    "https://cdn.jsdelivr.net",
                    # Si de veras necesitas code.jquery.com, añade:
                    # "https://code.jquery.com",
                    :https, # opcional si quieres permitir otros https versionados
                    -> { "'nonce-#{content_security_policy_nonce}'" }

  # Estilos y fuentes (usa Google Fonts si ya lo tienes en la vista)
  policy.style_src  :self, "https://cdnjs.cloudflare.com", "https://fonts.googleapis.com", :unsafe_inline
  policy.font_src   :self, "https://fonts.gstatic.com", :data
  policy.connect_src :self, :https, :ws, :wss, "https://cdn.jsdelivr.net"
  
  # *** Permite que TU propio sitio se iframee a sí mismo ***
  policy.frame_ancestors :self, "https://dashboard.lantiaintelligence.com", "https://lantiaintelligence.com"

  # *** Evita los errores por sourcemaps de jsDelivr (solo lectura) ***
  policy.connect_src :self, :https, :ws, :wss
end


# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

# Rails.application.config.content_security_policy do |policy|
#   policy.default_src :self, :https
#   policy.font_src    :self, :https, :data
#   policy.img_src     :self, :https, :data
#   policy.object_src  :none
#   policy.script_src  :self, :https
#   policy.style_src   :self, :https
#   # If you are using webpack-dev-server then specify webpack-dev-server host
#   policy.connect_src :self, :https, "http://localhost:3035", "ws://localhost:3035" if Rails.env.development?

#   # Specify URI for violation reports
#   # policy.report_uri "/csp-violation-report-endpoint"
# end

# If you are using UJS then enable automatic nonce generation
# Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }

# Set the nonce only to specific directives
# Rails.application.config.content_security_policy_nonce_directives = %w(script-src)

# Report CSP violations to a specified URI
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
# Rails.application.config.content_security_policy_report_only = true
