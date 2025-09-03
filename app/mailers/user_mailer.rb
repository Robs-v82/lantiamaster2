class UserMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM", "no-reply@lantiaintelligence.com")

  def password_reset(user, raw_token)
    @user  = user
    @token = raw_token
    @reset_url = edit_password_reset_url(@token, email: @user.mail)
    mail(to: @user.mail, subject: "Restablecer contraseña – Lantia Intelligence")
  end
end

