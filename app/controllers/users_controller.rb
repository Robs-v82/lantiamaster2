class UsersController < ApplicationController
  before_action :set_orgs, only: [:new, :create]
  before_action :require_admin!, only: [:admin, :new, :create]

  def new
    @user = User.new
  end

  def create
    ActiveRecord::Base.transaction do
      @member = Member.create!(member_params)

      random = "#{SecureRandom.urlsafe_base64(12)}Aa1"
      @user  = User.new(user_params.merge(member: @member))
      @user.mail = @user.mail.to_s.strip # normaliza espacios
      @user.password = random
      @user.password_confirmation = random
      @user.membership_type = 4
      @user.save! # si falla, saltará al rescue con mensajes

      if (d = parsed_membership_expiration).present?
        Subscription.create!(
          user: @user,
          plan_id: 4,
          current_period_end: d.end_of_day,
          status: 'active'
        )
      end

      verify_token = @user.generate_email_verification_token!
      reset_token  = @user.generate_password_reset!
      UserMailer.welcome_activation(@user, verify_token, reset_token).deliver_later
    end
    redirect_to users_admin_path, notice: 'Usuario creado y correo de activación enviado.'
  rescue ActiveRecord::RecordInvalid => e
    @user = e.record
    set_orgs
    flash.now[:alert] = @user.errors.full_messages.join(', ')
    Rails.logger.error "[Users#create] #{e.record.class} validation errors: #{e.record.errors.full_messages.join('; ')}"
    render :new, status: :unprocessable_entity
  end

  def admin
    @users = User
      .where(membership_type: 4)
      # .joins(member: :organization)
      # .where(organizations: { name: "GNP Seguros" })
      # .includes(member: :organization) # evita N+1 para nombre y organización
      .order(:id)
  end

  def edit
    @users = User
      .joins(:member)
      .includes(member: :organization)
      .where("EXISTS (SELECT 1 FROM subscriptions s WHERE s.user_id = users.id)")
      .order('members.firstname ASC')
  end

  def update_subscription
    require_admin!

    user = User.includes(:subscriptions).find(params[:id])

    # fecha enviada desde el formulario (YYYY-MM-DD)
    new_end = Date.parse(params.dig(:subscription, :current_period_end).to_s).end_of_day

    # suscripción vigente previa (si existe)
    old_active = user.subscriptions
                     .where(status: "active")
                     .order(current_period_end: :desc)
                     .first

    old_end = old_active&.current_period_end

    ActiveRecord::Base.transaction do
      # 1) si había una activa, la marcamos como no-activa para dejar 1 sola activa
      if old_active
        old_active.update!(status: "expired")
      end

      # 2) crear la nueva suscripción activa
      #    (siempre con plan_id 4 como lo vienes usando en UsersController#create)
      Subscription.create!(
        user: user,
        plan_id: 4,
        current_period_end: new_end,
        status: "active"
      )

      # 3) reflejar el membership_type (para que pueda hacer login de inmediato)
      user.update_columns(membership_type: 4, updated_at: Time.current)
    end

    # 4) mandar correo (lo implementamos en el siguiente paso)
    UserMailer.subscription_updated(user, old_end, new_end).deliver_later

    redirect_to users_edit_path, notice: "Suscripción actualizada."
  rescue ArgumentError
    redirect_to users_edit_path, alert: "Fecha inválida."
  end

  layout false, only: [:intro, :index]

  def preloader
    
  end

  def index
    @intro = true
    
  end

  def intro
  end

  def landing
  end



  private

    def set_orgs
    @organizations = Organization.where.not(:search_level=>nil)
                                 .order(:name)
                                 .select(:id, :name)
    end

    def user_params
      params.require(:user).permit(:mail)
    end

    def member_params
      params.require(:member).permit(:firstname, :lastname1, :lastname2, :organization_id)
    end

    def parsed_membership_expiration
      raw = params.dig(:user, :membership_expiration_on).to_s.strip
      return nil if raw.blank?
      Date.parse(raw) rescue nil
    end

end
