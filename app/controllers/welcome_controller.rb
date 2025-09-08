class WelcomeController < ApplicationController
  skip_before_action :require_login, only: [:show]

  def show
    user   = User.find_by(mail: params[:email])
    vt     = params[:token_v]
    rt     = params[:token_r]

    # 1) Verifica correo (idempotente)
    unless user&.valid_email_verification_token?(vt)
      return render plain: "Token de verificación inválido o expirado", status: :unprocessable_entity
    end
    user.mark_email_verified! unless user.email_verified?

    unless user.valid_password_reset_token?(rt, 48)  # ← 48 horas
      flash[:alert] = "El enlace para establecer contraseña expiró. Solicita uno nuevo."
      return redirect_to "/password"
    end

    # 2) Valida token de reset para llevar al formulario de contraseña
    # unless user.valid_password_reset_token?(rt)
    #   # Da salida útil si el reset expiró
    #   flash[:alert] = "El enlace para establecer contraseña expiró. Solicita uno nuevo."
    #   return redirect_to "/password"
    # end

    # 3) Redirige a tu flujo existente de edición de contraseña
    # (re-usa /password_resets/:token/edit?email=...)
    redirect_to "/password_resets/#{CGI.escape(rt)}/edit?email=#{CGI.escape(user.mail)}"
  end
end
