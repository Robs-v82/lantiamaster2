require 'stringio'

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

    # Crear un Briefing temporal SOLO para obtener parámetros (no guardado en BD)
    briefing_draft = create_briefing_from_params(report_type)

    # Leer el contenido del PDF directamente
    pdf_content = pdf_file.read
    pdf_file.rewind

    # Generar resumen del PDF usando el contenido
    result = ReportSummarizerService.new(pdf_content).call
    if result.ok?
      # Almacenar datos en sesión (NO guardar en BD aún)
      # El Briefing se crea recién en approve
      # Usar Base64 para encodear el contenido binario del PDF (session-safe UTF-8)
      session[:draft_briefing] = {
        report_type: report_type,
        month_number: briefing_draft.month_number,
        year: briefing_draft.year,
        number: briefing_draft.number,
        summary: result.summary,
        pdf_content_base64: Base64.strict_encode64(pdf_content),
        pdf_filename: pdf_file.original_filename,
        pdf_content_type: pdf_file.content_type
      }

      render json: {
        success: true,
        summary: result.summary,
        report_type: briefing_draft.report_type,
        formatted_date: briefing_draft.formatted_date
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

    # Crear el Briefing EN ESTE MOMENTO (no antes)
    briefing = Briefing.new(
      report_type: draft['report_type'],
      month_number: draft['month_number'],
      year: draft['year'],
      number: draft['number'],
      summary: summary.present? ? summary : draft['summary'],
      test_mode: test_mode
    )

    # Decodear el PDF desde Base64 y adjuntarlo
    pdf_binary = Base64.strict_decode64(draft['pdf_content_base64'])
    briefing.pdf.attach(
      io: StringIO.new(pdf_binary),
      filename: draft['pdf_filename'],
      content_type: draft['pdf_content_type']
    )

    briefing.save!

    # Asociar PDF con Month para reportes mensuales
    if briefing.monthly_report?
      briefing.associate_with_month
    end

    @briefing = briefing

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
