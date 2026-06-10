class CreateBriefings < ActiveRecord::Migration[6.0]
  def change
    create_table :briefings do |t|
      t.integer :number, comment: "Número de briefing, ej: 42"
      t.integer :month_number, comment: "Mes 1-12"
      t.integer :year
      t.text :summary, comment: "Resumen generado por IA, editable antes de enviar"
      t.datetime :sent_at, null: true, comment: "nil hasta que se confirma envío"
      t.string :sent_by, comment: "Mail del admin que aprobó"
      t.integer :recipients_count, default: 0
      t.string :report_type, null: false, comment: "reporte_riesgo, reporte_conflictividad, reporte_prospectiva, briefing_semanal"
      t.timestamps
    end

    add_index :briefings, [:year, :month_number, :report_type], unique: true, name: 'idx_briefings_uniqueness'
    add_index :briefings, :sent_at
    add_index :briefings, :report_type
  end
end
