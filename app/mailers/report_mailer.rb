class ReportMailer < ApplicationMailer
  default from: "plataforma@lantiaintelligence.com"

  def dispatch(user, briefing)
    @user = user
    @briefing = briefing
    @greeting = determine_greeting
    @download_url = generate_download_url

    # Log del resumen que se va a enviar
    Rails.logger.info("[ReportMailer#dispatch] Briefing #{briefing.id} - Resumen para renderizar (primeros 500 chars): #{briefing.summary[0..500].inspect}")

    subject_line = case briefing.report_type
                   when 'briefing_semanal'
                     "Briefing Semanal #{briefing.number.to_s.rjust(3, '0')} | Lantia Intelligence"
                   when 'reporte_riesgo'
                     "Reporte de Riesgo Social #{briefing.formatted_date} | Lantia Intelligence"
                   when 'reporte_conflictividad'
                     "Reporte de Conflictividad Social #{briefing.formatted_date} | Lantia Intelligence"
                   when 'reporte_prospectiva'
                     "Reporte de Prospectiva #{briefing.formatted_date} | Lantia Intelligence"
                   else
                     "Nuevo reporte | Lantia Intelligence"
                   end

    # Agregar prefijo de prueba si está en modo test
    subject_line = "[CORREO DE PRUEBA] #{subject_line}" if briefing.test_mode

    mail(to: @user.mail, subject: subject_line)
  end

  private

  def determine_greeting
    current_time = Time.now.to_i
    midnight = Time.now.beginning_of_day.to_i
    noon = Time.now.middle_of_day.to_i
    five_pm = Time.now.change(hour: 17).to_i
    eight_pm = Time.now.change(hour: 20).to_i

    if midnight.upto(noon).include?(current_time)
      "Buenos días"
    elsif noon.upto(eight_pm).include?(current_time)
      "Buenas tardes"
    elsif eight_pm.upto(midnight + 1.day).include?(current_time)
      "Buenas noches"
    else
      "Hola"
    end
  end

  def generate_download_url
    case @briefing.report_type
    when 'briefing_semanal'
      # Para briefings semanales, usar la URL pública de Active Storage
      Rails.application.routes.url_helpers.rails_blob_url(
        @briefing.pdf,
        only_path: false,
        host: Rails.application.config.action_mailer.default_url_options[:host]
      )
    when 'reporte_riesgo', 'reporte_conflictividad', 'reporte_prospectiva'
      # Para reportes mensuales, si existe Month asociado, usar su URL
      month = find_associated_month
      if month
        attachment_field = @briefing.attachment_field_for_month
        blob = month.public_send(attachment_field)
        Rails.application.routes.url_helpers.rails_blob_url(
          blob,
          only_path: false,
          host: Rails.application.config.action_mailer.default_url_options[:host]
        ) if blob.present?
      end
    end
  end

  def find_associated_month
    return nil unless @briefing.monthly_report?

    Quarter.joins(:year)
      .where(years: { name: @briefing.year.to_s })
      .first
      &.months
      &.find_by(name: "#{@briefing.year}_#{@briefing.month_number.to_s.rjust(2, '0')}")
  end
end
