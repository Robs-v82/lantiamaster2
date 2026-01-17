require 'bcrypt'
require 'securerandom'
require 'rotp'
require 'json'

class User < ApplicationRecord
  PASSWORD_RESET_TTL = 48.hours
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

  before_validation { self.mail = mail.to_s.strip }
  validates :mail, format:  { with: VALID_EMAIL_REGEX }
  validates :mail, uniqueness: { case_sensitive: false }
  # La complejidad se exige solo cuando se asigna/actualiza password
  validates :password, format: { with: VALID_PASSWORD_REGEX }, allow_nil: true

  belongs_to :member, optional: true
  has_many :hits          
  has_many :keys,          dependent: :delete_all
  has_many :queries,       dependent: :delete_all
  has_many :subscriptions, dependent: :delete_all

  has_many :lrvl_membership_expirations,
           class_name: "LrvlMembershipExpiration",
           dependent: :delete_all

  has_secure_token :api_key

  before_create :skip_api_key_generation

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

    cost = if ActiveModel::SecurePassword.min_cost
             BCrypt::Engine::MIN_COST
           else
             BCrypt::Engine.cost
           end

    digest = BCrypt::Password.create(raw, cost: cost)
    update!(
      reset_password_token_digest: digest,
      reset_password_sent_at: Time.current
    )
    raw
  end

  # Valida token recibido: existe, no expiró y coincide con digest.
  # TTL por defecto: 2 horas (ajustable).
  def valid_password_reset_token?(raw, ttl: PASSWORD_RESET_TTL)
    return false if reset_password_sent_at.blank? || reset_password_token_digest.blank?
    return false if reset_password_sent_at < ttl.ago

    BCrypt::Password.new(reset_password_token_digest).is_password?(raw)
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

  # === MFA (TOTP) ===
  def mfa_enabled?
    mfa_enabled_at.present? && mfa_totp_secret.present?
  end

  # Genera secreto y códigos de respaldo. NO habilita hasta que verifiques el primer TOTP.
  # Devuelve { provisioning_uri:, backup_codes:[] } para mostrar en la UI (backup codes: sólo una vez).
  def mfa_begin_setup!(issuer: "Lantia", account: nil, codes_count: 10)
    account ||= mail
    secret = ROTP::Base32.random_base32
    update!(mfa_totp_secret: secret)
    totp   = ROTP::TOTP.new(mfa_totp_secret, issuer: issuer)
    uri    = totp.provisioning_uri(account)

    raw_codes = Array.new(codes_count) { SecureRandom.hex(4) } # 8 hex chars
    digests   = raw_codes.map { |c| BCrypt::Password.create(c) }
    update!(mfa_backup_codes_digest: JSON.dump(digests))

    { provisioning_uri: uri, backup_codes: raw_codes }
  end

  # Verifica TOTP. drift=1 permite ±1 paso (~60s). Anti-replay con mfa_last_used_step.
  # Si es el primer uso correcto, marca mfa_enabled_at.
  def verify_totp!(code, drift: 1)
    return false if mfa_totp_secret.blank?
    totp = ROTP::TOTP.new(mfa_totp_secret)
    code = code.to_s.gsub(/\s+/, '')

    now = Time.now
    used_step = nil

    (-drift..drift).each do |offset|
      t    = now + (offset * 30)
      step = (t.to_i / 30)               # ← en vez de totp.timecode(t)
      next if mfa_last_used_step.present? && step <= mfa_last_used_step

      if totp.verify(code, at: t, drift_behind: 0, drift_ahead: 0)
        used_step = step
        break
      end
    end

    return false unless used_step
    update_columns(mfa_last_used_step: used_step)
    update_columns(mfa_enabled_at: Time.current) unless mfa_enabled?
    true
  end

  # Usa un backup code (1 sola vez). Devuelve true si coincide y lo invalida.
  def use_backup_code!(code)
    return false if mfa_backup_codes_digest.blank?
    digests = JSON.parse(mfa_backup_codes_digest)
    idx = digests.find_index do |d|
      begin
        BCrypt::Password.new(d).is_password?(code.to_s.strip)
      rescue BCrypt::Errors::InvalidHash
        false
      end
    end
    return false if idx.nil?
    digests.delete_at(idx)
    update_columns(mfa_backup_codes_digest: JSON.dump(digests))
    true
  end

  def disable_mfa!
    update!(mfa_totp_secret: nil, mfa_enabled_at: nil, mfa_backup_codes_digest: nil, mfa_last_used_step: nil)
  end

  private

  def skip_api_key_generation
    self.api_key = nil
  end

end



