class DetentionsMonthlyExport < ApplicationRecord
  has_many :detention_captures, dependent: :nullify

  validates :year, :month, presence: true
  validates :year, uniqueness: { scope: :month, message: 'Export already exists for this month' }

  scope :recent, -> { order(year: :desc, month: :desc) }
  scope :pending, -> { where(status: 'pending_validation') }
  scope :validated, -> { where(status: 'validated') }

  def self.find_or_create_current_month
    now = Date.today
    find_or_create_by(year: now.year, month: now.month) do |export|
      export.capture_start_date = now.beginning_of_month
      export.capture_end_date = now.end_of_month
    end
  end

  def generate_final_csv
    require 'csv'

    captures = detention_captures
      .where(status: 'validated')
      .where(deleted_at: nil)
      .order(incident_date: :asc)

    csv_content = CSV.generate(headers: true) do |csv|
      csv << [
        'Día', 'Mes', 'Año', 'Estado', 'full_code', 'Municipio',
        'Abatido', 'Detenidos', 'Organización', 'Grupo afiliado',
        'Nombre', 'Apellido Paterno', 'Apellido Materno', 'Alias',
        'Género', 'Edad', 'Posición liderazgo', 'Rol',
        'SEDENA', 'SEMAR', 'GN', 'SSCP', 'FGR', 'SSP-Estatal',
        'FGE/PGJ', 'Policía municipal', 'Otro', 'Fuente'
      ]

      captures.each do |capture|
        csv << [
          capture.incident_date.day,
          capture.incident_date.month,
          capture.incident_date.year % 100,
          capture.estado,
          capture.full_code,
          capture.municipio,
          capture.abatido.nil? ? '' : (capture.abatido ? 'Sí' : ''),
          capture.detenidos || '',
          capture.organizacion,
          capture.grupo_afiliado,
          capture.nombre,
          capture.apellido_paterno,
          capture.apellido_materno,
          capture.alias,
          capture.genero,
          capture.edad,
          capture.posicion_liderazgo,
          capture.rol,
          capture.sedena ? 1 : '',
          capture.semar ? 1 : '',
          capture.gn ? 1 : '',
          capture.sscp ? 1 : '',
          capture.fgr ? 1 : '',
          capture.ssp_estatal ? 1 : '',
          capture.fge_pgj ? 1 : '',
          capture.policia_municipal ? 1 : '',
          capture.otro ? 1 : '',
          capture.source_url
        ]
      end
    end

    filename = "detenciones_#{year}_#{month.to_s.rjust(2, '0')}.csv"
    filepath = File.join(Rails.root, 'public', 'exports', filename)
    FileUtils.mkdir_p(File.dirname(filepath))
    File.write(filepath, csv_content)

    update(csv_file_path: filepath)
    csv_content
  end
end
