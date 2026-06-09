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

  def self.normalize_name(name)
    return nil if name.blank?
    name.downcase
      .gsub(/[àáäâ]/, 'a')
      .gsub(/[èéëê]/, 'e')
      .gsub(/[ìíïî]/, 'i')
      .gsub(/[òóöô]/, 'o')
      .gsub(/[ùúüû]/, 'u')
      .gsub(/[ñ]/, 'n')
      .gsub(/\s+/, ' ')
      .strip
  end

  def self.find_duplicates(capture)
    week_start = capture.incident_date - 6.days
    week_end = capture.incident_date + 6.days

    norm_nombre = normalize_name(capture.nombre)
    norm_apellido = normalize_name(capture.apellido_paterno)
    norm_alias = normalize_name(capture.alias)

    duplicates = where.not(id: capture.id).where(estado: capture.estado)

    potential_dups = duplicates.where(
      'incident_date BETWEEN ? AND ?', week_start, week_end
    ).map do |other|
      {
        record: other,
        norm_nombre: normalize_name(other.nombre),
        norm_apellido: normalize_name(other.apellido_paterno),
        norm_alias: normalize_name(other.alias)
      }
    end

    potential_dups.select do |dup|
      dup_record = dup[:record]

      (norm_nombre.present? && dup[:norm_nombre] == norm_nombre && norm_apellido.present? && dup[:norm_apellido] == norm_apellido) ||
        (norm_nombre.present? && dup[:norm_nombre] == norm_nombre && norm_apellido.blank? && dup[:norm_apellido].blank?) ||
        (norm_alias.present? && dup[:norm_alias] == norm_alias)
    end.map { |dup| dup[:record] }
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
