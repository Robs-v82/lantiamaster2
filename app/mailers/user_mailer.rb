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
end

