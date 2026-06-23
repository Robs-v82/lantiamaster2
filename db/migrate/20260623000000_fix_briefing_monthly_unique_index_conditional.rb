class FixBriefingMonthlyUniqueIndexConditional < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    # Remover el índice incondicional que está prohibiendo múltiples briefing_semanal
    remove_index :briefings, name: 'idx_briefing_monthly_unique' if index_exists?(:briefings, [:year, :month_number, :report_type], name: 'idx_briefing_monthly_unique')

    # Crear un índice condicional que solo aplique a los reportes mensuales, NO a briefing_semanal
    # Esto permite múltiples briefing_semanal en el mismo mes, pero garantiza unicidad para los otros tipos
    add_index :briefings, [:year, :month_number, :report_type],
              unique: true,
              name: 'idx_briefing_monthly_unique',
              where: "report_type != 'briefing_semanal'",
              algorithm: :concurrently
  end
end
