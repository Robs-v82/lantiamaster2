class ReauthController < ApplicationController
  layout "application"

  def new
    redirect_to "/frontpage" and return unless current_user_safe
  end

  def create
    u = current_user_safe
    unless u && u.authenticate(params[:password].to_s)
      audit!("reauth_failure", user: u, meta: {reason:"bad_password"})
      flash.now[:alert] = "Contraseña incorrecta."
      render :new, status: :unprocessable_entity and return
    end
    audit!("reauth_success", user: u)
    session[:reauth_at] = Time.current.to_i
    dest = session.delete(:return_to_after_reauth).presence || "/"
    redirect_to dest, notice: "Verificación completada."
  end
end