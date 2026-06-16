class CleanAndFixBriefingsIndexes < ActiveRecord::Migration[6.0]
  def change
    # Primero: eliminar todos los índices viejos si existen
    remove_index :briefings, name: 'idx_briefings_uniqueness' if index_exists?(:briefings, [:year, :month_number, :report_type], name: 'idx_briefings_uniqueness')
    remove_index :briefings, name: 'idx_briefing_semanal_number' if index_exists?(:briefings, :number, name: 'idx_briefing_semanal_number')
    remove_index :briefings, name: 'idx_briefings_monthly_uniqueness' if index_exists?(:briefings, [:year, :month_number, :report_type], name: 'idx_briefings_monthly_uniqueness')
    remove_index :briefings, name: 'idx_briefing_number_unique' if index_exists?(:briefings, :number, name: 'idx_briefing_number_unique')
    remove_index :briefings, name: 'idx_briefing_monthly_unique' if index_exists?(:briefings, [:year, :month_number, :report_type], name: 'idx_briefing_monthly_unique')

    # Segundo: Crear índices simples sin conflictos
    add_index :briefings, :number, unique: true, name: 'idx_briefing_number_unique'
    add_index :briefings, [:year, :month_number, :report_type], unique: true, name: 'idx_briefing_monthly_unique'
  end
end
