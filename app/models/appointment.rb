# app/models/appointment.rb
class Appointment < ApplicationRecord
  belongs_to :member
  belongs_to :role
  belongs_to :organization, optional: true
  belongs_to :county,       optional: true

  # 0=day, 1=month, 2=year, 3=unknown
  enum start_precision: { day: 0, month: 1, year: 2, unknown: 3 }, _prefix: :start_prec
  enum end_precision:   { day: 0, month: 1, year: 2, unknown: 3 }, _prefix: :end_prec

  validates :period, presence: true

  # Consultas útiles con daterange (PostgreSQL)
  scope :current, -> { where("period @> CURRENT_DATE") }
  scope :at,      ->(date) { where("period @> ?::date", date.to_date) }
  scope :between, ->(from, to) {
  where("period && daterange(?::date, ?::date, '[]')", from.to_date, to.to_date)
  }

  # Helpers para presentar fechas inclusivas (ajustando el extremo derecho si es exclusivo)
  def start_date
    period.begin
  end

  def end_date
    return nil unless period.end
    period.exclude_end? ? (period.end - 1.day) : period.end
  end

  # —— CREADORES CON FECHA PARCIAL —— 
  # Caso "estaba en el cargo el día X" => [X, X+1)
  def self.from_point_date(member:, role:, date:, organization: nil, county: nil)
    create!(
      member: member,
      role: role,
      organization: organization,
      county: county,
      period: (date...date + 1.day),
      start_precision: :day,
      end_precision: :day
    )
  end

  # Periodo mensual (ej. enero 2023) => [2023-01-01, 2023-02-01)
  def self.from_month(member:, role:, year:, month:, organization: nil, county: nil)
    from = Date.new(year, month, 1)
    to   = from.next_month
    create!(
      member: member,
      role: role,
      organization: organization,
      county: county,
      period: (from...to),
      start_precision: :month,
      end_precision: :month
    )
  end

  # Periodo anual (ej. 2021) => [2021-01-01, 2022-01-01)
  def self.from_year(member:, role:, year:, organization: nil, county: nil)
    from = Date.new(year, 1, 1)
    to   = from.next_year
    create!(
      member: member,
      role: role,
      organization: organization,
      county: county,
      period: (from...to),
      start_precision: :year,
      end_precision: :year
    )
  end
end
