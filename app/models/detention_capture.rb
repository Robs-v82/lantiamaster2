class DetentionCapture < ApplicationRecord
  belongs_to :detentions_monthly_export, optional: true
  belongs_to :organization, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :this_month, -> { where(incident_date: Date.today.beginning_of_month..Date.today.end_of_month) }
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

      # Criterio 1: Nombre + Apellido Paterno exactos
      exact_name_apellido = (norm_nombre.present? && dup[:norm_nombre] == norm_nombre &&
                             norm_apellido.present? && dup[:norm_apellido] == norm_apellido)

      # Criterio 2: Solo nombre (ambos sin apellido paterno)
      only_name = (norm_nombre.present? && dup[:norm_nombre] == norm_nombre &&
                   norm_apellido.blank? && dup[:norm_apellido].blank?)

      # Criterio 3: Alias exacto
      alias_match = (norm_alias.present? && dup[:norm_alias] == norm_alias)

      # Criterio 4: Nombres/apellidos parciales - uno es subset del otro
      partial_match = names_are_partial_match(
        capture.nombre, capture.apellido_paterno, capture.apellido_materno,
        dup_record.nombre, dup_record.apellido_paterno, dup_record.apellido_materno
      )

      exact_name_apellido || only_name || alias_match || partial_match
    end.map { |dup| dup[:record] }
  end

  def self.names_are_partial_match(name1, apellido1, apellido_materno1,
                                    name2, apellido2, apellido_materno2)
    # Construir arrays de tokens normalizados para cada registro
    tokens1 = [name1, apellido1, apellido_materno1]
                .compact
                .flat_map { |n| n.split(/\s+/) }
                .map { |t| normalize_name(t) }
                .uniq
                .sort

    tokens2 = [name2, apellido2, apellido_materno2]
                .compact
                .flat_map { |n| n.split(/\s+/) }
                .map { |t| normalize_name(t) }
                .uniq
                .sort

    # Requiere al menos 2 tokens en cada set para evitar falsos positivos
    return false if tokens1.length < 2 || tokens2.length < 2

    # Verifica si uno es subset del otro
    (tokens1 - tokens2).empty? || (tokens2 - tokens1).empty?
  end

  def merge_with_duplicate(new_record)
    updates = {}
    update_reasons = []

    # ────────────────────────────────────────────────────────────────
    # CAMPOS DE NOMBRE (privilegiar completitud)
    # ────────────────────────────────────────────────────────────────

    # Nombre: usar el que tenga más palabras (nombre compuesto)
    new_nombre_words = (new_record.nombre || '').split(/\s+/).length
    old_nombre_words = (self.nombre || '').split(/\s+/).length
    if new_nombre_words > old_nombre_words && new_record.nombre.present?
      updates[:nombre] = new_record.nombre
      update_reasons << "nombre: '#{self.nombre}' → '#{new_record.nombre}' (#{new_nombre_words} palabras vs #{old_nombre_words})"
    end

    # Apellido Paterno: agregar si falta
    if self.apellido_paterno.blank? && new_record.apellido_paterno.present?
      updates[:apellido_paterno] = new_record.apellido_paterno
      update_reasons << "apellido_paterno: agregado '#{new_record.apellido_paterno}'"
    end

    # Apellido Materno: agregar si falta
    if self.apellido_materno.blank? && new_record.apellido_materno.present?
      updates[:apellido_materno] = new_record.apellido_materno
      update_reasons << "apellido_materno: agregado '#{new_record.apellido_materno}'"
    end

    # Alias: agregar si falta
    if self.alias.blank? && new_record.alias.present?
      updates[:alias] = new_record.alias
      update_reasons << "alias: agregado '#{new_record.alias}'"
    end

    # ────────────────────────────────────────────────────────────────
    # CAMPOS DICOTÓMICOS (usar OR lógico: true si alguno es true)
    # ────────────────────────────────────────────────────────────────

    dichotomous_fields = [:sedena, :semar, :gn, :sscp, :fgr, :ssp_estatal, :fge_pgj, :policia_municipal, :otro]

    dichotomous_fields.each do |field|
      old_val = self.send(field) || false
      new_val = new_record.send(field) || false

      if !old_val && new_val
        updates[field] = true
        update_reasons << "#{field}: marcado como true (nueva fuente identificó participación)"
      end
    end

    # ────────────────────────────────────────────────────────────────
    # CAMPOS DE TEXTO GENERAL (agregar si falta)
    # ────────────────────────────────────────────────────────────────

    text_fields = [:organizacion, :grupo_afiliado, :rol, :posicion_liderazgo, :genero]

    text_fields.each do |field|
      if self.send(field).blank? && new_record.send(field).present?
        updates[field] = new_record.send(field)
        update_reasons << "#{field}: agregado '#{new_record.send(field)}'"
      end
    end

    # ────────────────────────────────────────────────────────────────
    # CAMPOS NUMÉRICOS (usar el mayor valor)
    # ────────────────────────────────────────────────────────────────

    if new_record.edad.present? && (self.edad.blank? || new_record.edad > self.edad)
      updates[:edad] = new_record.edad
      update_reasons << "edad: actualizada a #{new_record.edad}"
    end

    if new_record.detenidos.present? && (self.detenidos.blank? || new_record.detenidos > self.detenidos)
      updates[:detenidos] = new_record.detenidos
      update_reasons << "detenidos: actualizado a #{new_record.detenidos}"
    end

    # ────────────────────────────────────────────────────────────────
    # NOTAS DE VALIDACIÓN (concatenar información)
    # ────────────────────────────────────────────────────────────────

    if new_record.validation_notes.present?
      existing_notes = self.validation_notes || ""
      if !existing_notes.include?(new_record.validation_notes)
        updates[:validation_notes] = "#{existing_notes}\n[Merged] #{new_record.validation_notes}".strip
        update_reasons << "validation_notes: información adicional agregada"
      end
    end

    # ────────────────────────────────────────────────────────────────
    # APLICAR ACTUALIZACIONES
    # ────────────────────────────────────────────────────────────────

    if updates.any?
      self.update(updates)
      return {
        success: true,
        updates_applied: updates.keys,
        update_reasons: update_reasons,
        fields_updated_count: updates.length
      }
    else
      return {
        success: true,
        updates_applied: [],
        update_reasons: ["Sin cambios necesarios - registro ya contiene información completa"],
        fields_updated_count: 0
      }
    end
  end

  def self.monthly_summary(year, month)
    date_start = Date.new(year, month, 1)
    date_end = date_start.end_of_month

    {
      total_captures: where(incident_date: date_start..date_end).count,
      validated: where(incident_date: date_start..date_end, status: 'validated').count,
      pending_review: where(incident_date: date_start..date_end, status: 'pending_review').count,
      duplicates: where(incident_date: date_start..date_end, status: 'duplicate').count,
      rejected: where(incident_date: date_start..date_end, status: 'rejected').count
    }
  end

  # Análisis de duplicados por nivel
  def self.analyze_duplicates(year = nil, month = nil)
    year ||= Date.today.year
    month ||= Date.today.month

    date_start = Date.new(year, month, 1)
    date_end = date_start.end_of_month

    captures = where(incident_date: date_start..date_end, deleted_at: nil).to_a

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
