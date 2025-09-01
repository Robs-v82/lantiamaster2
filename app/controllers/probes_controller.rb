class ProbesController < ApplicationController
  # Evita filtros comunes que redirigen al frontpage o exigen login/CSRF.
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :require_login, raise: false
  skip_before_action :verify_authenticity_token, raise: false
  skip_before_action :redirect_to_frontpage, raise: false

  def session_probe
    session[:probe] ||= SecureRandom.hex(8)  # fuerza escritura de sesión
    render plain: "ok"                       # 200 OK (sin redirección)
  end
end
