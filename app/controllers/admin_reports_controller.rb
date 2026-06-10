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

    # Crear un Briefing temporal SOLO para obtener parámetros (no guardado en BD)
    briefing_draft = create_briefing_from_params(report_type)

    # Generar resumen del PDF (pasar el archivo directamente, no el objeto)
    result = ReportSummarizerService.new(pdf_file).call
    if result.ok?
      # Guardar el PDF temporalmente en ActiveStorage para obtener su clave
      temp_briefing = Briefing.new(
        report_type: report_type,
        month_number: briefing_draft.month_number,
        year: briefing_draft.year,
        number: briefing_draft.number
      )
      temp_briefing.pdf.attach(pdf_file)
      temp_briefing.save! # Guardar solo para obtener la clave del PDF

      # Almacenar datos en sesión para usar en approve
      session[:draft_briefing] = {
        report_type: temp_briefing.report_type,
        month_number: temp_briefing.month_number,
        year: temp_briefing.year,
        number: temp_briefing.number,
        summary: result.summary,
        briefing_id: temp_briefing.id, # Guardar ID del Briefing temporal
        pdf_key: temp_briefing.pdf.key
      }

      render json: {
        success: true,
        summary: result.summary,
        report_type: temp_briefing.report_type,
        formatted_date: temp_briefing.formatted_date
      }
    else
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
      count = identify_test_emails.length
    else
      count = calculate_recipient_count
    end

    render json: { recipients_count: count }
  end

  def approve
    summary = params[:summary]
    test_mode = ActiveModel::Type::Boolean.new.cast(params[:test_mode])

    # Obtener datos del draft desde sesión
    draft = session[:draft_briefing]
    unless draft
      return render json: { error: "Sesión expirada. Por favor, carga el reporte nuevamente." }, status: :unprocessable_entity
    end

    # Obtener el Briefing temporal creado durante upload
    temp_briefing = Briefing.find(draft['briefing_id'])

    # Actualizar con test_mode y summary
    temp_briefing.update(
      summary: summary.present? ? summary : draft['summary'],
      test_mode: test_mode
    )
    @briefing = temp_briefing

    # Identificar emails según test_mode
    if test_mode
      test_emails = identify_test_emails
      @briefing.save_test_emails(test_emails)
      recipients_emails = test_emails
      recipients_count = test_emails.length
    else
      recipients_emails = fetch_active_user_emails
      recipients_count = recipients_emails.length
    end

    user = User.find(session[:user_id])
    ReportDispatchJob.perform_later(@briefing.id, user.mail)

    # Limpiar la sesión
    session[:draft_briefing] = nil

    render json: {
      success: true,
      briefing_id: @briefing.id,
      report_type: @briefing.report_type,
      formatted_date: @briefing.formatted_date,
      recipients_count: recipients_count,
      recipients_emails: recipients_emails,
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

  def fetch_active_user_emails
    User.where(membership_type: 4)
      .joins(:subscriptions)
      .where(subscriptions: { status: "active" })
      .where("subscriptions.current_period_end > ?", Access::MembershipGate.now_mx)
      .distinct
      .pluck(:mail)
      .sort
  end
end
