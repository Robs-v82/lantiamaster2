# frozen_string_literal: true
class MfaController < ApplicationController
  before_action :require_login, except: [:challenge, :verify]
  before_action :load_user_for_setup, only: [:setup, :enable, :disable]

  # GET /mfa/setup  → genera secreto + backup codes, y muestra el URI (o QR)
  def setup
    if @user.mfa_enabled?
      redirect_to "/account", notice: "MFA ya está habilitado" and return
    end

    if @user.mfa_totp_secret.blank?
      data = @user.mfa_begin_setup!(issuer: "Lantia", account: @user.mail)
      @provisioning_uri = data[:provisioning_uri]
      @backup_codes     = data[:backup_codes]  # se muestran solo una vez
    else
      # Reusar el secreto existente (NO volver a generarlo)
      totp = ROTP::TOTP.new(@user.mfa_totp_secret, issuer: "Lantia")
      @provisioning_uri = totp.provisioning_uri(@user.mail)
      @backup_codes     = []  # no vuelvas a mostrar códigos
    end
  end

  # POST /mfa/enable  → verifica el primer TOTP y habilita MFA
  def enable
    code = params[:code]
    unless @user.verify_totp!(code)
      flash[:alert] = "Código inválido"
      redirect_to "/mfa/setup" and return
    end
    redirect_to "/account", notice: "MFA habilitado correctamente"
  end

  # GET /mfa/challenge  → segundo factor durante login
  def challenge
    uid = session[:pending_user_id]
    @user = User.find_by(id: uid)
    head :unauthorized and return unless @user
  end

  # POST /mfa/verify  → valida TOTP o backup code y completa el login
  def verify
    uid = session[:pending_user_id]
    @user = User.find_by(id: uid)
    head :unauthorized and return unless @user

    code = params[:code].to_s.strip
    ok = @user.verify_totp!(code) || @user.use_backup_code!(code)
    unless ok
      flash[:alert] = "Código inválido"
      redirect_to "/mfa/challenge" and return
    end

    session.delete(:pending_user_id)
    session[:user_id] = @user.id
    redirect_to "/frontpage"
  end

  # POST /mfa/disable  → pide contraseña + TOTP/backup para deshabilitar
  def disable
    unless @user.authenticate(params[:current_password].to_s)
      flash[:alert] = "Contraseña incorrecta"
      redirect_to "/account" and return
    end
    code = params[:code].to_s.strip
    ok = @user.verify_totp!(code) || @user.use_backup_code!(code)
    unless ok
      flash[:alert] = "Código inválido"
      redirect_to "/account" and return
    end
    @user.disable_mfa!
    redirect_to "/account", notice: "MFA deshabilitado"
  end

  private
  def load_user_for_setup
    @user = User.find(session[:user_id])
    head :unauthorized unless @user
  end
end