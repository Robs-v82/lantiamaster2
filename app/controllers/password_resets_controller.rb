class PasswordResetsController < ActionController::Base
  protect_from_forgery with: :null_session

  def create
    user = User.find_by(mail: params[:email])
    if user
      token = user.generate_password_reset!
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

  # Muestra formulario si el token es válido
  def edit
    @user  = User.find_by(mail: params[:email])
    @token = params[:token]
    if @user&.valid_password_reset_token?(@token)
      render :edit
    else
      render plain: "Token inválido o expirado", status: :unprocessable_entity
    end
  end

  # Procesa formulario
  def update
    user = User.find_by(mail: params[:email])
    token = params[:token]
    unless user&.valid_password_reset_token?(token)
      render plain: "Token inválido o expirado", status: :unprocessable_entity and return
    end

    if params[:password].present? && params[:password] == params[:password_confirmation]
      user.password = params[:password]
      user.password_confirmation = params[:password_confirmation]
      if user.save
        user.clear_password_reset!
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