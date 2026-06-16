class Briefing < ApplicationRecord
  has_one_attached :pdf

  validates :report_type, inclusion: {
    in: %w[reporte_riesgo reporte_conflictividad reporte_prospectiva briefing_semanal],
    message: "debe ser uno de: reporte_riesgo, reporte_conflictividad, reporte_prospectiva, briefing_semanal"
  }

  validates :number, presence: true,
            uniqueness: true,
            if: proc { |b| b.report_type == 'briefing_semanal' },
            message: "de briefing ya existe"

  validates :month_number, :year, presence: true,
            if: proc { |b| b.report_type != 'briefing_semanal' }

  validates :month_number, inclusion: { in: 1..12 },
            if: proc { |b| b.report_type != 'briefing_semanal' }

  validates :year, :month_number, :report_type,
            uniqueness: { scope: [:month_number, :year],
                          message: "ya existe un reporte de este tipo para ese mes/año" },
            if: proc { |b| b.report_type != 'briefing_semanal' }

  scope :sent, -> { where.not(sent_at: nil) }
  scope :pending, -> { where(sent_at: nil) }
  scope :by_type, ->(type) { where(report_type: type) }
  scope :recent, -> { order(year: :desc, month_number: :desc) }

  def test_emails_array
    return [] if test_emails.blank?
    JSON.parse(test_emails)
  rescue JSON::ParseError
    []
  end

  def save_test_emails(emails)
    self.test_emails = emails.is_a?(Array) ? emails.to_json : emails
    save!
  end

  def delivered_emails_array
    return [] if delivered_emails.blank?
    JSON.parse(delivered_emails)
  rescue JSON::ParseError
    []
  end

  def mark_email_delivered!(email)
    current = delivered_emails_array
    return if current.include?(email)
    update_column(:delivered_emails, (current << email).to_json)
  end

  def month_name
    I18n.t("date.month_names")[month_number]
  end

  def formatted_date
    "#{month_name} de #{year}"
  end

  def monthly_report?
    %w[reporte_riesgo reporte_conflictividad reporte_prospectiva].include?(report_type)
  end

  def attachment_field_for_month
    case report_type
    when 'reporte_riesgo'
      :violence_report
    when 'reporte_conflictividad'
      :social_report
    when 'reporte_prospectiva'
      :forecast_report
    else
      nil
    end
  end

  def associate_with_month(pdf_blob = nil)
    return unless monthly_report?

    field = attachment_field_for_month
    return unless field

    month = find_or_create_month
    return unless month

    if pdf_blob
      month.public_send("#{field}=", pdf_blob)
      month.save!
    elsif pdf.present?
      month.public_send("#{field}=", pdf.blob)
      month.save!
    end
  end

  private

  def find_or_create_month
    quarter = Quarter.joins(:year).where(years: { name: year.to_s }).first
    quarter ||= create_quarter_for_year

    return nil unless quarter

    month_name = I18n.t("date.month_names")[month_number]
    month = Month.where(name: "#{year}_#{month_number.to_s.rjust(2, '0')}", quarter_id: quarter.id).first

    unless month
      month = Month.create!(
        name: "#{year}_#{month_number.to_s.rjust(2, '0')}",
        quarter_id: quarter.id,
        first_day: Date.new(year, month_number, 1)
      )
    end

    month
  end

  def create_quarter_for_year
    year_record = Year.find_or_create_by!(name: year.to_s)
    quarter_num = ((month_number - 1) / 3) + 1
    Quarter.find_or_create_by!(
      name: "Q#{quarter_num} #{year}",
      year_id: year_record.id,
      first_day: Date.new(year, ((quarter_num - 1) * 3) + 1, 1)
    )
  end
end
