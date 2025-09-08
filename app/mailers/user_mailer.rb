class UserMailer < ApplicationMailer
  # default from: ENV.fetch("MAILER_FROM", "no-reply@lantiaintelligence.com")
  	default from: "plataforma@lantiaintelligence.com"


	def greeting
		current_time = Time.now.to_i
		midnight = Time.now.beginning_of_day.to_i
		noon = Time.now.middle_of_day.to_i
		five_pm = Time.now.change(:hour => 17 ).to_i
		eight_pm = Time.now.change(:hour => 20 ).to_i
		if midnight.upto(noon).include?(current_time)
			@greeting = "Buenos días"
		elsif noon.upto(eight_pm).include?(current_time)
			@greeting = "Buenas tardes"
		elsif eight_pm.upto(midnight + 1.day).include?(current_time)
			@greeting = "Buenas noches"
		end	
	end

  def password_reset(user, raw_token)
    @greeting = greeting
    @user  = user
    @token = raw_token
    @reset_url = edit_password_reset_url(@token, email: @user.mail)
    mail(to: @user.mail, subject: "Restablecer contraseña – Lantia Intelligence")
  end

  def email_verification(user, token)
    @user = user
    @url  = verify_email_url(token: token, email: user.mail)
    mail to: user.mail, subject: "Verifica tu correo"
  end

	def welcome_activation(user, verify_token, reset_token)
	  @user = user

	  # URL que espera la vista
	  @verify_and_set_password_url = verify_and_set_password_url(
	    token_v: verify_token,
	    token_r: reset_token,
	    email:   user.mail
	  )

	  # Tiempos que espera la vista
	  @sent_at         = Time.current
	  @verify_deadline = @sent_at + 48.hours      # verificación de correo
	  @reset_deadline  = @sent_at + 60.minutes    # establecer contraseña

	  # Si tu HTML muestra un solo vencimiento (@expires_at), usa el más estricto:
	  @expires_at = [@verify_deadline, @reset_deadline].min

	  mail to: user.mail, subject: "Activa tu cuenta – Lantia Intelligence"
	end
  
end

