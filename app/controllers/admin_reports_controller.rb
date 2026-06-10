class AdminReportsController < ApplicationController
  before_action :require_admin!
  before_action :set_briefing, only: [:review]

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

    # Validar PDF antes de procesar
    validation = validate_pdf(pdf_file)
    unless validation[:ok]
      return render json: { error: validation[:error] }, status: :unprocessable_entity
    end

    # Crear Briefing en BD
    briefing = create_briefing_from_params(report_type)
    briefing.pdf.attach(
      io: pdf_file.open,
      filename: pdf_file.original_filename,
      content_type: pdf_file.content_type
    )
    briefing.save!

    # Generar resumen del PDF
    result = ReportSummarizerService.new(briefing.pdf.download).call

    if result.ok?
      briefing.update(summary: result.summary)

      # Guardar en sesión para usar en approve
      session[:draft_briefing_id] = briefing.id

      render json: {
        success: true,
        summary: result.summary,
        report_type: briefing.report_type,
        formatted_date: briefing.formatted_date,
        briefing_id: briefing.id
      }
    else
      briefing.destroy
      render json: { error: result.error }, status: :unprocessable_entity
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
      recipients_emails = identify_test_emails
      count = recipients_emails.length
    else
      recipients_emails = fetch_active_user_emails
      count = recipients_emails.length
    end

    render json: {
      recipients_count: count,
      recipients_emails: recipients_emails
    }
  end

  def approve
    summary = params[:summary]
    test_mode = ActiveModel::Type::Boolean.new.cast(params[:test_mode])
    briefing_id = session[:draft_briefing_id]

    unless briefing_id
      return render json: { error: "Sesión expirada. Por favor, carga el reporte nuevamente." }, status: :unprocessable_entity
    end

    # Obtener el Briefing creado en upload
    briefing = Briefing.find(briefing_id)
    briefing.update(
      summary: summary.present? ? summary : briefing.summary,
      test_mode: test_mode
    )

    # Asociar PDF con Month para reportes mensuales
    if briefing.monthly_report?
      briefing.associate_with_month
    end

    # Identificar emails según test_mode
    if test_mode
      test_emails = identify_test_emails
      briefing.save_test_emails(test_emails)
      recipients_emails = test_emails
      recipients_count = test_emails.length
    else
      recipients_emails = fetch_active_user_emails
      recipients_count = recipients_emails.length
    end

    user = User.find(session[:user_id])
    ReportDispatchJob.perform_later(briefing.id, user.mail)

    # Limpiar la sesión
    session[:draft_briefing_id] = nil

    render json: {
      success: true,
      briefing_id: briefing.id,
      report_type: briefing.report_type,
      formatted_date: briefing.formatted_date,
      recipients_count: recipients_count,
      recipients_emails: recipients_emails,
      test_mode: test_mode,
      test_emails: test_mode ? briefing.test_emails_array : []
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

  def fetch_active_user_emails
    User.where(membership_type: 4)
      .joins(:subscriptions)
      .where(subscriptions: { status: "active" })
      .where("subscriptions.current_period_end > ?", Access::MembershipGate.now_mx)
      .distinct
      .pluck(:mail)
      .sort
  end

  def validate_pdf(pdf_file)
    # Verificar tamaño (máximo 20MB)
    if pdf_file.size > 20.megabytes
      return { ok: false, error: "PDF demasiado grande. Máximo permitido: 20MB" }
    end

    # Verificar content-type
    unless pdf_file.content_type == 'application/pdf'
      return { ok: false, error: "El archivo debe ser un PDF válido" }
    end

    { ok: true }
  end
end
