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

    already_delivered = briefing.delivered_emails_array
    successful_count = already_delivered.length

    users.each do |user|
      next if already_delivered.include?(user.mail)
      begin
        ReportMailer.dispatch(user, briefing).deliver_now
        briefing.mark_email_delivered!(user.mail)
        successful_count += 1
      rescue => e
        Rails.logger.warn(
          "[ReportDispatchJob] Error enviando a #{user.mail}: #{e.class} - #{e.message}"
        )
      end
    end

    # Decrementar el contador de jobs pendientes
    briefing.decrement!(:pending_dispatch_jobs)

    # Solo marcar como enviado y almacenar sent_by si NO es modo prueba
    if briefing.test_mode
      briefing.update(recipients_count: successful_count)
      Rails.logger.info(
        "[ReportDispatchJob] Briefing #{briefing.id} enviado en MODO PRUEBA a #{successful_count} usuarios (test_mode: true, pending_jobs: #{briefing.pending_dispatch_jobs})"
      )
      # Eliminar el Briefing solo después de que todos los jobs hayan terminado
      if briefing.pending_dispatch_jobs <= 0
        briefing.destroy!
        Rails.logger.info(
          "[ReportDispatchJob] Briefing #{briefing.id} eliminado después de prueba (test_mode: true, todos los jobs completados)"
        )
      end
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
      .where(mail: ApplicationController::ADMIN_EMAILS)
      .distinct
  end
end
