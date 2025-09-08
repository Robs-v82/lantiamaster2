# app/models/user.rb
require 'bcrypt'
require 'securerandom'

class User < ApplicationRecord
  # === Validaciones existentes (tuyas) ===
  VALID_PASSWORD_REGEX = /\A
    (?=.{7,})          # 7+ caracteres
    (?=.*\d)           # al menos 1 dígito
    (?=.*[a-z])        # al menos 1 minúscula
    (?=.*[A-Z])        # al menos 1 mayúscula
  /x
  VALID_EMAIL_REGEX = /\A([\w+\-]\.?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i

  # Hash de contraseñas (usa password_digest)
  has_secure_password

  # Soporte existente para "recovery_password" (lo mantengo como estaba)
  has_secure_password :recovery_password, validations: false

  validates :mail, format:  { with: VALID_EMAIL_REGEX }
  validates :mail, uniqueness: { case_sensitive: false }
  # La complejidad se exige solo cuando se asigna/actualiza password
  validates :password, format: { with: VALID_PASSWORD_REGEX }, allow_nil: true

  belongs_to :member, optional: true
  has_many :keys
  has_many :queries

  # =========================
  #  Password reset seguro
  # =========================
  # Requiere columnas:
  #   reset_password_token_digest:string
  #   reset_password_sent_at:datetime
  #
  # Genera token aleatorio (devuelve el token "plano" para el enlace),
  # guarda su digest y marca timestamp de envío.
  def generate_password_reset!
    raw = SecureRandom.urlsafe_base64(32)
    digest = BCrypt::Password.create(raw)
    update!(
      reset_password_token_digest: digest,
      reset_password_sent_at: Time.current
    )
    raw
  end

  # Valida token recibido: existe, no expiró y coincide con digest.
  # TTL por defecto: 2 horas (ajustable).
  # def valid_password_reset_token?(raw, ttl: 2.hours)
  #   return false if reset_password_sent_at.blank? || reset_password_sent_at < ttl.ago
  #   return false if reset_password_token_digest.blank?

  #   BCrypt::Password.new(reset_password_token_digest) == raw
  # rescue BCrypt::Errors::InvalidHash
  #   false
  # end


  def valid_password_reset_token?(token, ttl_hours = nil)
    # ttl por defecto = 60 minutos si no te pasan uno
    ttl_hours ||= 1

    return false if password_reset_digest.blank? || password_reset_sent_at.blank?
    BCrypt::Password.new(password_reset_digest).is_password?(token) &&
      password_reset_sent_at >= ttl_hours.hours.ago
  end

  # Invalida token (llamar tras cambiar contraseña).
  def clear_password_reset!
    update!(reset_password_token_digest: nil, reset_password_sent_at: nil)
  end

  def membership_active?
    Access::MembershipGate.active?(self)
  end

  def current_plan_id
    Access::MembershipGate.current_plan_id(self)
  end

  def current_membership_expiration
    Access::MembershipGate.current_expiration(self)
  end

  def rotate_session_version!
    update_column(:session_version, SecureRandom.hex(16))
  end 

  # --- Login lock/backoff ---
  def locked?
    locked_until.present? && locked_until > Time.current
  end

  def minutes_locked_remaining
    return 0 unless locked?
    ((locked_until - Time.current) / 60.0).ceil
  end

  def register_failed_login!
    # A partir del 5º intento, bloqueo exponencial: 1,2,4,8... min (máx. 60)
    new_count = (failed_login_attempts || 0) + 1
    penalty_minutes =
      if new_count <= 4
        0
      else
        [2 ** (new_count - 5), 60].min
      end
    new_locked_until =
      if penalty_minutes.zero?
        locked_until # sin cambio
      else
        base = locked_until&.future? ? locked_until : Time.current
        base + penalty_minutes.minutes
      end

    update_columns(
      failed_login_attempts: new_count,
      locked_until: new_locked_until
    )
  end

  def clear_failed_logins!
    update_columns(failed_login_attempts: 0, locked_until: nil)
  end

  def generate_email_verification_token!
    token  = SecureRandom.urlsafe_base64(32)
    cost   = if ActiveModel::SecurePassword.min_cost
               BCrypt::Engine::MIN_COST
             else
               BCrypt::Engine.cost
             end
    digest = BCrypt::Password.create(token, cost: cost)

    update!(
      email_verification_digest: digest,
      email_verification_sent_at: Time.current
    )
    token
  end

  def valid_email_verification_token?(token)
    return false if email_verification_digest.blank?
    BCrypt::Password.new(email_verification_digest).is_password?(token) &&
      !email_verification_expired?
  end

  def email_verification_expired?(ttl_hours = 48)
    return true if email_verification_sent_at.blank?
    email_verification_sent_at < ttl_hours.hours.ago
  end

  def mark_email_verified!
    update!(
      email_verified_at: Time.current,
      email_verification_digest: nil,
      email_verification_sent_at: nil
    )
  end

  def email_verified?
    email_verified_at.present?
  end

end



