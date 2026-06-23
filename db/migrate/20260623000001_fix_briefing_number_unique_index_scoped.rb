class FixBriefingNumberUniqueIndexScoped < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    # Remover el índice global incondicional en number
    remove_index :briefings, name: 'idx_briefing_number_unique' if index_exists?(:briefings, :number, name: 'idx_briefing_number_unique')

    # Crear un índice único que solo aplique a briefing_semanal, scoped por year y month_number
    # Esto permite que cada mes tenga sus propios números secuenciales (276 en junio, 276 en julio, etc.)
    add_index :briefings, [:number, :year, :month_number],
              unique: true,
              name: 'idx_briefing_number_unique',
              where: "report_type = 'briefing_semanal'",
              algorithm: :concurrently
  end
end
