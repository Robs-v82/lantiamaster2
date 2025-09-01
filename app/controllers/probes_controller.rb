class ProbesController < ApplicationController
  def session_probe
    session[:probe] ||= SecureRandom.hex(8) # fuerza escritura de sesión
    render plain: "ok"
  end
end
