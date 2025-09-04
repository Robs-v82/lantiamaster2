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
  def valid_password_reset_token?(raw, ttl: 2.hours)
    return false if reset_password_sent_at.blank? || reset_password_sent_at < ttl.ago
    return false if reset_password_token_digest.blank?

    BCrypt::Password.new(reset_password_token_digest) == raw
  rescue BCrypt::Errors::InvalidHash
    false
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
end



