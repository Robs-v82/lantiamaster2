class PasswordResetsController < ActionController::Base
  protect_from_forgery with: :null_session

  # POST /password_resets   params: email
  def create
    user = User.find_by(mail: params[:email])
    if user
      token = user.generate_password_reset!
      if Rails.env.production?
        head :no_content
      else
        render json: { token: token, email: user.mail }
      end
    else
      head :no_content
    end
  end

  # GET /password_resets/:token/edit?email=...
  def edit
    user = User.find_by(mail: params[:email])
    if user&.valid_password_reset_token?(params[:token])
      render plain: "ok"
    else
      render plain: "Invalid or expired token", status: :unprocessable_entity
    end
  end

  # PATCH /password_resets/:token?email=...  params: password, password_confirmation
  def update
    user = User.find_by(mail: params[:email])
    unless user&.valid_password_reset_token?(params[:token])
      render json: { error: "Invalid or expired token" }, status: :unprocessable_entity and return
    end

    if params[:password].present? && params[:password] == params[:password_confirmation]
      user.password = params[:password]
      user.password_confirmation = params[:password_confirmation]
      if user.save
        user.clear_password_reset!
        head :no_content
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: "Password confirmation mismatch" }, status: :unprocessable_entity
    end
  end
end