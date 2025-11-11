# app/controllers/welcome_controller.rb
class WelcomeController < ApplicationController
  skip_before_action :require_login, only: [:show]
  before_action :set_logging_context

  def show
    raw_email = params[:email].to_s
    raw_vt    = params[:token_v].to_s
    raw_rt    = params[:token_r].to_s

    # Normalización defensiva: muchos clientes convierten '+' a ' ' en querystrings
    vt = normalize_token(raw_vt)
    rt = normalize_token(raw_rt)

    Rails.logger.info(log_kv(
      event: "welcome#show.start",
      email: raw_email,
      vt_hint: hint_token(vt),
      rt_hint: hint_token(rt),
      vt_changed_on_normalize: (raw_vt != vt),
      rt_changed_on_normalize: (raw_rt != rt)
    ))

    user = find_user_case_insensitive(raw_email)

    if user.nil?
      Rails.logger.warn(log_kv(
        event: "welcome#show.user_not_found",
        email: raw_email
      ))
      return render plain: "Token de verificación inválido o expirado", status: :unprocessable_entity
    end

    begin
      unless user.valid_email_verification_token?(vt)
        Rails.logger.warn(log_kv(
          event: "welcome#show.invalid_email_token",
          user_id: user.id,
          vt_hint: hint_token(vt)
        ))
        return render plain: "Token de verificación inválido o expirado", status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error(log_kv(
        event: "welcome#show.valid_email_verification_token_error",
        user_id: user.id,
        error_class: e.class.name,
        error_message: e.message
      ))
      raise
    end

    if !user.email_verified?
      user.mark_email_verified!
      Rails.logger.info(log_kv(
        event: "welcome#show.email_marked_verified",
        user_id: user.id
      ))
    else
      Rails.logger.info(log_kv(
        event: "welcome#show.email_already_verified",
        user_id: user.id
      ))
    end

    begin
      unless user.valid_password_reset_token?(rt, ttl: 48.hours)
        Rails.logger.warn(log_kv(
          event: "welcome#show.password_reset_token_invalid_or_expired",
          user_id: user.id,
          rt_hint: hint_token(rt),
          ttl_hours: 48
        ))
        flash[:alert] = "El enlace para establecer contraseña expiró. Solicita uno nuevo."
        return redirect_to "/password"
      end
    rescue => e
      Rails.logger.error(log_kv(
        event: "welcome#show.valid_password_reset_token_error",
        user_id: user.id,
        error_class: e.class.name,
        error_message: e.message
      ))
      raise
    end

    Rails.logger.info(log_kv(
      event: "welcome#show.redirect_password_resets_edit",
      user_id: user.id
    ))
    redirect_to "/password_resets/#{CGI.escape(rt)}/edit?email=#{CGI.escape(user.mail)}"
  end

  private

  # Si tu columna es 'mail' y no garantizas minúsculas al guardar,
  # esta búsqueda tolera variaciones de mayúsc/minúsculas.
  def find_user_case_insensitive(email)
    return nil if email.blank?
    User.where("LOWER(mail) = ?", email.downcase).first
  end

  # Convierte espacios a '+' para tokens base64/urlsafe rotos por clientes/copiado.
  def normalize_token(token)
    t = token.strip
    # Si te consta que son urlsafe_base64, quizá no haga falta; pero en producción
    # es frecuente que un '+' llegue como ' ' (espacio) por malas codificaciones.
    t.tr(" ", "+")
  end

  # No loggeamos el token completo; solo longitud y extremos.
  def hint_token(token)
    return { present: false } if token.blank?
    { present: true, length: token.length, head: token[0,4], tail: token[-4,4] }
  end

  def set_logging_context
    req = request
    Rails.logger.info(log_kv(
      event: "welcome#show.request_context",
      request_id: req.request_id,
      ip: req.remote_ip,
      ua: req.user_agent,
      referer: req.referer
    ))
  end

  # Logging estilo “key=value” para que sea grep/stackdriver friendly
  def log_kv(hash)
    hash.map { |k,v| "#{k}=#{v.inspect}" }.join(" ")
  end
end
