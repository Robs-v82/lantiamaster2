class DetentionCapture < ApplicationRecord
  belongs_to :detentions_monthly_export, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :this_month, -> { where(capture_date: Date.today.beginning_of_month..Date.today.end_of_month) }
  scope :active, -> { where(deleted_at: nil) }
  scope :by_status, ->(status) { where(status: status) }

  validates :capture_hash, presence: true, uniqueness: true
  validates :incident_date, :estado, :municipio, :full_code, presence: true

  before_create :ensure_capture_date

  def self.generate_hash(attributes)
    require 'digest'
    content = [
      attributes[:estado],
      attributes[:municipio],
      attributes[:incident_date],
      attributes[:detenidos],
      attributes[:organizacion],
      (attributes[:nombres] || []).sort.join('|')
    ].join('||')

    Digest::SHA1.hexdigest(content)
  end

  def self.find_duplicates(capture)
    where.not(id: capture.id)
      .where(estado: capture.estado)
      .where(municipio: capture.municipio)
      .where('incident_date BETWEEN ? AND ?',
             capture.incident_date - 1.day,
             capture.incident_date + 1.day)
      .where(detenidos: (capture.detenidos - 2)..(capture.detenidos + 2))
  end

  def self.monthly_summary(year, month)
    date_start = Date.new(year, month, 1)
    date_end = date_start.end_of_month

    {
      total_captures: where(capture_date: date_start..date_end).count,
      validated: where(capture_date: date_start..date_end, status: 'validated').count,
      pending_review: where(capture_date: date_start..date_end, status: 'pending_review').count,
      duplicates: where(capture_date: date_start..date_end, status: 'duplicate').count,
      rejected: where(capture_date: date_start..date_end, status: 'rejected').count
    }
  end

  def soft_delete
    update(deleted_at: Time.current, status: 'deleted')
  end

  private

  def ensure_capture_date
    self.capture_date ||= Date.today
  end
end
