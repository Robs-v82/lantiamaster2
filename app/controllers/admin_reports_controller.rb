class AdminReportsController < ApplicationController
  before_action :require_admin!
  before_action :set_briefing, only: [:review, :approve]

  def index
    @briefing_form = Briefing.new
    @sent_briefings = Briefing.sent.recent.limit(20)
  end

  def upload
    report_type = params[:report_type]
    pdf_file = params[:pdf]

    if pdf_file.blank?
      return render json: { error: "PDF requerido" }, status: :unprocessable_entity
    end

    briefing = create_briefing_from_params(report_type)

    if briefing.save
      briefing.pdf.attach(pdf_file)

      result = generate_summary(briefing)
      if result.ok?
        briefing.update(summary: result.summary)
        render json: {
          success: true,
          briefing_id: briefing.id,
          summary: briefing.summary,
          report_type: briefing.report_type,
          formatted_date: briefing.formatted_date
        }
      else
        briefing.destroy
        render json: { error: result.error }, status: :unprocessable_entity
      end
    else
      render json: { error: briefing.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error("[AdminReportsController#upload] #{e.class} - #{e.message}")
    render json: { error: "Error procesando PDF: #{e.message}" }, status: :unprocessable_entity
  end

  def review
    render json: {
      id: @briefing.id,
      summary: @briefing.summary,
      report_type: @briefing.report_type,
      formatted_date: @briefing.formatted_date,
      user_count: calculate_recipient_count
    }
  end

  def calculate_recipients
    test_mode = params[:test_mode] == 'true'

    if test_mode
      count = identify_test_emails.length
    else
      count = calculate_recipient_count
    end

    render json: { recipients_count: count }
  end

  def approve
    summary = params[:summary]
    test_mode = params[:test_mode] == 'true'

    @briefing.update(test_mode: test_mode)
    @briefing.update(summary: summary) if summary.present?

    # Identificar emails según test_mode
    if test_mode
      test_emails = identify_test_emails
      @briefing.save_test_emails(test_emails)
      recipients_count = test_emails.length
    else
      recipients_count = calculate_recipient_count
    end

    user = User.find(session[:user_id])
    ReportDispatchJob.perform_later(@briefing.id, user.mail)

    render json: {
      success: true,
      briefing_id: @briefing.id,
      report_type: @briefing.report_type,
      formatted_date: @briefing.formatted_date,
      recipients_count: recipients_count,
      test_mode: test_mode,
      test_emails: test_mode ? @briefing.test_emails_array : []
    }
  rescue => e
    Rails.logger.error("[AdminReportsController#approve] #{e.class} - #{e.message}")
    render json: { error: "Error aprobando reporte: #{e.message}" }, status: :unprocessable_entity
  end

  private

  def set_briefing
    @briefing = Briefing.find(params[:id])
  end

  def require_admin!
    redirect_to root_path, alert: "No autorizado" unless admin_user?
  end

  def create_briefing_from_params(report_type)
    case report_type
    when 'briefing_semanal'
      Briefing.new(
        number: params[:number]&.to_i,
        month_number: params[:month]&.to_i || Date.today.month,
        year: params[:year]&.to_i || Date.today.year,
        report_type: 'briefing_semanal'
      )
    when 'reporte_riesgo', 'reporte_conflictividad', 'reporte_prospectiva'
      Briefing.new(
        number: nil,
        month_number: params[:month]&.to_i,
        year: params[:year]&.to_i,
        report_type: report_type
      )
    else
      raise "Tipo de reporte inválido: #{report_type}"
    end
  end

  def generate_summary(briefing)
    ReportSummarizerService.new(briefing.pdf.blob).call
  end

  def calculate_recipient_count
    User.where(membership_type: 4)
      .joins(:subscriptions)
      .where(subscriptions: { status: "active" })
      .where("subscriptions.current_period_end > ?", Access::MembershipGate.now_mx)
      .distinct
      .count
  end

  def identify_test_emails
    User.where(membership_type: 4)
      .joins(:subscriptions)
      .where(subscriptions: { status: "active" })
      .where("subscriptions.current_period_end > ?", Access::MembershipGate.now_mx)
      .where("mail LIKE ?", "%@lantiaintelligence.com")
      .distinct
      .pluck(:mail)
      .sort
  end
end
