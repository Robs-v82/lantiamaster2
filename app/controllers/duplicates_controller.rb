class DuplicatesController < ApplicationController
  # Skip authentication for development dashboard
  skip_before_action :verify_authenticity_token, only: [:mark_as_duplicate, :unmark_duplicate]

  before_action :set_analysis, only: [:index, :show]

  # GET /duplicates
  def index
    @tab = params[:tab] || 'level1'
    render :dashboard
  end

  # GET /duplicates/level1
  def level1_details
    @confirmed_dupes = DetentionCapture.find_confirmed_duplicates
    @groups_count = @confirmed_dupes.size
    @total_records_affected = @confirmed_dupes.values.flatten.size
  end

  # GET /duplicates/level2
  def level2_details
    @probable_dupes = DetentionCapture.find_probable_duplicates
    @groups_count = @probable_dupes.size
    @total_records_affected = @probable_dupes.values.map { |v| v[:records] }.flatten.size
  end

  # GET /duplicates/operations
  def operations_details
    @operations = DetentionCapture.find_multi_person_operations
    @total_operations = @operations.size
    @total_persons = @operations.values.flatten.size
  end

  # GET /duplicates/incomplete
  def incomplete_details
    @incomplete = DetentionCapture.find_incomplete_records
  end

  # POST /duplicates/:id/mark_as_duplicate
  def mark_as_duplicate
    capture = DetentionCapture.find(params[:id])
    keep_id = params[:keep_id] || params[:id]

    if capture.id.to_s == keep_id.to_s
      render json: { error: 'Cannot mark the same record' }, status: :unprocessable_entity
      return
    end

    keep_record = DetentionCapture.find(keep_id)

    # Log la acción
    DuplicationLog.create(
      source_record_id: keep_record.id,
      duplicate_record_id: capture.id,
      action: 'marked_as_duplicate',
      reason: params[:reason] || 'manual_review',
      user_id: current_user&.id,
      notes: params[:notes]
    )

    # Marcar como duplicado
    capture.update(status: 'duplicate', validation_notes: "Duplicate of record ##{keep_record.id}")

    render json: { success: true, message: "Record ##{capture.id} marked as duplicate of ##{keep_record.id}" }
  end

  # POST /duplicates/:id/unmark
  def unmark_duplicate
    capture = DetentionCapture.find(params[:id])

    if capture.status != 'duplicate'
      render json: { error: 'Record is not marked as duplicate' }, status: :unprocessable_entity
      return
    end

    capture.update(status: 'captured', validation_notes: nil)

    DuplicationLog.create(
      duplicate_record_id: capture.id,
      action: 'unmarked_as_duplicate',
      reason: 'manual_correction',
      user_id: current_user&.id,
      notes: params[:notes]
    )

    render json: { success: true, message: "Record ##{capture.id} unmarked as duplicate" }
  end

  # GET /duplicates/export_report
  def export_report
    analysis = DetentionCapture.analyze_duplicates

    csv_content = generate_csv_report(analysis)

    send_data csv_content,
      filename: "duplicates_analysis_#{Date.today}.csv",
      type: 'text/csv',
      disposition: 'attachment'
  end

  private

  def set_analysis
    @analysis = DetentionCapture.analyze_duplicates
    @stats = @analysis[:stats]
  end

  def generate_csv_report(analysis)
    require 'csv'

    CSV.generate do |csv|
      csv << ['ANÁLISIS DE DUPLICADOS', Date.today]
      csv << []

      # Estadísticas generales
      csv << ['ESTADÍSTICAS GENERALES']
      csv << ['Total de registros', @stats[:total_records]]
      csv << ['Full codes únicos', @stats[:unique_full_codes]]
      csv << ['Nombres únicos', @stats[:unique_names]]
      csv << ['Registros con full_code', @stats[:records_with_full_code]]
      csv << ['Registros con nombre completo', @stats[:records_with_full_name]]
      csv << ['Registros con organización', @stats[:records_with_org]]
      csv << []

      # Nivel 1: Duplicados confirmados
      csv << ['NIVEL 1: DUPLICADOS CONFIRMADOS', "#{analysis[:level_1].size} grupos"]
      csv << ['Grupo', 'ID', 'Nombre', 'Municipio', 'Estado', 'Fecha', 'Organización']
      analysis[:level_1].each do |group_key, records|
        records.each_with_index do |record, idx|
          csv << [
            (idx == 0 ? group_key : ''),
            record.id,
            "#{record.nombre} #{record.apellido_paterno}",
            record.municipio,
            record.estado,
            record.incident_date,
            record.organizacion
          ]
        end
        csv << []
      end

      # Nivel 2: Duplicados probables
      csv << ['NIVEL 2: DUPLICADOS PROBABLES', "#{analysis[:level_2].size} grupos"]
      csv << ['Grupo', 'ID', 'Nombre', 'Municipio', 'Fecha', 'Sospechoso']
      analysis[:level_2].each do |group_key, dup_data|
        records = dup_data[:records]
        suspicious = dup_data[:suspicious]
        records.each_with_index do |record, idx|
          csv << [
            (idx == 0 ? group_key : ''),
            record.id,
            "#{record.nombre} #{record.apellido_paterno}",
            record.municipio,
            record.incident_date,
            (idx == 0 ? (suspicious ? 'SÍ' : 'NO') : '')
          ]
        end
        csv << []
      end

      # Registros incompletos
      csv << ['REGISTROS CON DATOS INCOMPLETOS']
      csv << ['Tipo', 'Cantidad']
      incomplete = analysis[:incomplete_records]
      csv << ['Sin nombre', incomplete[:sin_nombre].size]
      csv << ['Sin apellido paterno', incomplete[:sin_apellido].size]
      csv << ['Sin organización', incomplete[:sin_organizacion].size]
      csv << ['Sin full_code', incomplete[:sin_full_code].size]
    end
  end
end
