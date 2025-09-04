class ReauthController < ApplicationController
  layout "application"

  def new
    redirect_to "/login" and return unless current_user_safe
  end

  def create
    u = current_user_safe
    unless u && u.authenticate(params[:password].to_s)
      flash.now[:alert] = "Contraseña incorrecta."
      render :new, status: :unprocessable_entity and return
    end
    session[:reauth_at] = Time.current.to_i
    dest = session.delete(:return_to_after_reauth).presence || "/"
    redirect_to dest, notice: "Verificación completada."
  end
end