class PasswordResetsController < ActionController::Base
  layout "application" 
  include AuthAudit
  # protect_from_forgery with: :null_session

  private
  def find_user_by_email
    email = params[:email].to_s.strip.downcase
    User.where('LOWER(mail) = ?', email).first
  end

  public
  def create
    user = find_user_by_email
    if user
      token = user.generate_password_reset!
      audit!("reset_request", user: user)
      if Rails.env.production?
        UserMailer.password_reset(user, token).deliver_later
        head :no_content
      else
        begin; UserMailer.password_reset(user, token).deliver_now; rescue; end
        render json: { token: token, email: user.mail }
      end
    else
      head :no_content
    end
  end

  def edit
    @user  = find_user_by_email
    @token = params[:token]
    if @user&.valid_password_reset_token?(@token)
      render :edit
    else
      render plain: "Token inválido o expirado", status: :unprocessable_entity
    end
  end

  def update
    user  = find_user_by_email
    token = params[:token]
    unless user&.valid_password_reset_token?(token)
      render plain: "Token inválido o expirado", status: :unprocessable_entity and return
    end
    if params[:password].present? && params[:password] == params[:password_confirmation]
      user.password = params[:password]
      user.password_confirmation = params[:password_confirmation]
      if user.save
        audit!("reset_success", user: user)
        user.clear_password_reset!
        user.rotate_session_version!
        reset_session
        redirect_to "/frontpage", notice: "Contraseña actualizada. Inicia sesión."
      else
        @user = user; @token = token
        flash.now[:alert] = user.errors.full_messages.join(", ")
        render :edit, status: :unprocessable_entity
      end
    else
      @user = user; @token = token
      flash.now[:alert] = "Las contraseñas no coinciden."
      render :edit, status: :unprocessable_entity
    end
  end
end
