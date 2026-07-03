class DetentionCapture < ApplicationRecord
  belongs_to :detentions_monthly_export, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :this_month, -> { where(capture_date: Date.today.beginning_of_month..Date.today.end_of_month) }
  scope :active, -> { where(deleted_at: nil) }
  scope :by_status, ->(status) { where(status: status) }

  validates :capture_hash, presence: true, uniqueness: true
  validates :incident_date, :estado, :municipio, presence: true

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

  # Análisis de duplicados por nivel
  def self.analyze_duplicates(year = nil, month = nil)
    year ||= Date.today.year
    month ||= Date.today.month

    date_start = Date.new(year, month, 1)
    date_end = date_start.end_of_month

    captures = where(capture_date: date_start..date_end, deleted_at: nil).to_a

    {
      level_1: find_confirmed_duplicates(captures),
      level_2: find_probable_duplicates(captures),
      multi_person_ops: find_multi_person_operations(captures),
      incomplete_records: find_incomplete_records(captures),
      stats: compute_duplicate_stats(captures)
    }
  end

  # Nivel 1: Duplicados confirmados (mismo full_code + nombre + municipio + fecha)
  def self.find_confirmed_duplicates(captures = all)
    confirmed = {}

    captures
      .select { |c| c.full_code.present? && c.nombre.present? && c.status != 'duplicate' }
      .group_by { |c| "#{c.full_code}|#{normalize_name(c.nombre)}|#{normalize_name(c.apellido_paterno)}|#{c.municipio}" }
      .select { |k, v| v.size > 1 }
      .each { |k, v| confirmed[k] = v.sort_by(&:incident_date) }

    confirmed
  end

  # Nivel 2: Duplicados probables (mismo nombre + municipio, fechas cercanas)
  def self.find_probable_duplicates(captures = all, days_threshold = 30)
    probable = {}

    captures
      .select { |c| c.nombre.present? && c.municipio.present? && c.status != 'duplicate' }
      .group_by { |c| "#{normalize_name(c.nombre)}|#{normalize_name(c.apellido_paterno)}|#{c.municipio}|#{c.estado}" }
      .select { |k, v| v.size > 1 }
      .each do |k, v|
        sorted = v.sort_by(&:incident_date)
        # Verificar si las diferencias de fecha son sospechosas
        suspicious = false
        sorted.each_cons(2) do |a, b|
          diff = (b.incident_date - a.incident_date).to_i
          if diff.between?(6, days_threshold) && diff != 0
            suspicious = true
            break
          end
        end
        probable[k] = { records: sorted, suspicious: suspicious } if suspicious
      end

    probable
  end

  # Operativos legítimos con múltiples personas (mismo día, mismo municipio)
  def self.find_multi_person_operations(captures = all, min_persons = 2)
    operations = {}

    captures
      .group_by { |c| "#{c.estado}|#{c.municipio}|#{c.incident_date}" }
      .select { |k, v| v.size >= min_persons }
      .each { |k, v| operations[k] = v.sort_by { |c| c.nombre.to_s } }

    operations
  end

  # Registros con datos incompletos
  def self.find_incomplete_records(captures = all)
    {
      sin_nombre: captures.select { |c| c.nombre.blank? },
      sin_apellido: captures.select { |c| c.nombre.present? && c.apellido_paterno.blank? },
      sin_organizacion: captures.select { |c| c.organizacion.blank? || c.organizacion == "No identificada" },
      sin_full_code: captures.select { |c| c.full_code.blank? || c.full_code.empty? }
    }
  end

  # Estadísticas de duplicados
  def self.compute_duplicate_stats(captures = all)
    {
      total_records: captures.count,
      unique_full_codes: captures.select { |c| c.full_code.present? }.map(&:full_code).uniq.size,
      unique_names: captures.select { |c| c.nombre.present? }.map { |c| "#{c.nombre}#{c.apellido_paterno}" }.uniq.size,
      records_with_full_code: captures.select { |c| c.full_code.present? }.count,
      records_with_full_name: captures.select { |c| c.nombre.present? && c.apellido_paterno.present? }.count,
      records_with_org: captures.select { |c| c.organizacion.present? && c.organizacion != "No identificada" }.count
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
