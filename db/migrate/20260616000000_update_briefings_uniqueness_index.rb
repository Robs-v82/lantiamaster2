class UpdateBriefingsUniquenessIndex < ActiveRecord::Migration[6.0]
  def change
    # Remover el índice actual
    remove_index :briefings, name: 'idx_briefings_uniqueness'

    # Nuevo índice: briefing_semanal por número (único)
    add_index :briefings, :number, unique: true,
              where: "(report_type = 'briefing_semanal')",
              name: 'idx_briefing_semanal_number'

    # Nuevo índice: otros reportes por (year, month_number, report_type)
    add_index :briefings, [:year, :month_number, :report_type], unique: true,
              where: "(report_type != 'briefing_semanal')",
              name: 'idx_briefings_monthly_uniqueness'
  end
end
