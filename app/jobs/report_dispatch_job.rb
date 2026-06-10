class ReportDispatchJob < ApplicationJob
  queue_as :default

  def perform(briefing_id, sent_by_email)
    briefing = Briefing.find(briefing_id)
    return if briefing.sent_at.present? # Ya fue enviado

    users = fetch_active_users
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

    briefing.update!(
      sent_at: Time.current,
      sent_by: sent_by_email,
      recipients_count: successful_count
    )

    Rails.logger.info(
      "[ReportDispatchJob] Briefing #{briefing.id} despachado a #{successful_count} usuarios"
    )
  end

  private

  def fetch_active_users
    User.where(membership_type: 4)
      .joins(:subscriptions)
      .where(subscriptions: { status: "active" })
      .where("subscriptions.current_period_end > ?", Access::MembershipGate.now_mx)
      .distinct
  end
end
