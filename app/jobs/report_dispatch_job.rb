class ReportDispatchJob < ApplicationJob
  queue_as :default

  def perform(briefing_id, sent_by_email)
    briefing = Briefing.find(briefing_id)
    return if briefing.sent_at.present? # Ya fue enviado

    if briefing.test_mode
      users = fetch_test_users
    else
      users = fetch_active_users
    end

    successful_count = 0

    users.each do |user|
      begin
        ReportMailer.dispatch(user, briefing).deliver_later
        successful_count += 1
      rescue => e
        Rails.logger.warn(
          "[ReportDispatchJob] Error enviando a #{user.mail}: #{e.class} - #{e.message}"
        )
      end
    end

    # Solo marcar como enviado y almacenar sent_by si NO es modo prueba
    if briefing.test_mode
      briefing.update!(recipients_count: successful_count)
      Rails.logger.info(
        "[ReportDispatchJob] Briefing #{briefing.id} enviado en MODO PRUEBA a #{successful_count} usuarios (test_mode: true)"
      )
      # Eliminar el Briefing después de prueba para permitir reutilizar el mismo mes/tipo en modo producción
      briefing.destroy!
      Rails.logger.info(
        "[ReportDispatchJob] Briefing #{briefing.id} eliminado después de prueba (test_mode: true)"
      )
    else
      briefing.update!(
        sent_at: Time.current,
        sent_by: sent_by_email,
        recipients_count: successful_count
      )
      Rails.logger.info(
        "[ReportDispatchJob] Briefing #{briefing.id} despachado a #{successful_count} usuarios (modo producción)"
      )
    end
  end

  private

  def fetch_active_users
    User.where(membership_type: 4)
      .joins(:subscriptions)
      .where(subscriptions: { status: "active" })
      .where("subscriptions.current_period_end > ?", Access::MembershipGate.now_mx)
      .distinct
  end

  def fetch_test_users
    User.where(membership_type: 4)
      .joins(:subscriptions)
      .where(subscriptions: { status: "active" })
      .where("subscriptions.current_period_end > ?", Access::MembershipGate.now_mx)
      .where("mail LIKE ?", "%@lantiaintelligence.com")
      .distinct
  end
end
