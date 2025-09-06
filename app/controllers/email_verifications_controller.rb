class EmailVerificationsController < ApplicationController
  skip_before_action :require_login, only: [:verify]  # si usas ese filtro

  def send_link
    user = current_user || User.find_by(mail: params[:email])
    return head :not_found unless user
    token = user.generate_email_verification_token!
    UserMailer.email_verification(user, token).deliver_now
    head :no_content
  end

  def verify
    user  = User.find_by(mail: params[:email])
    token = params[:token]
    unless user&.valid_email_verification_token?(token)
      render plain: "Token inválido o expirado", status: :unprocessable_entity and return
    end
    user.mark_email_verified!
    redirect_to "/frontpage", notice: "Correo verificado"
  end
end
