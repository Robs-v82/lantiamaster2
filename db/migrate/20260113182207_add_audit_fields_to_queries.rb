class AddAuditFieldsToQueries < ActiveRecord::Migration[6.0]
  def change
    add_column :queries, :source, :string                 # "manual" | "api"
    add_column :queries, :status_code, :integer           # 200, 422, 429, etc (si quieres)
    add_column :queries, :success, :boolean, default: true, null: false
    add_column :queries, :request_id, :string
    add_column :queries, :result_count, :integer          # members encontrados (count)
    add_column :queries, :query_label, :string            # texto “bonito” para mostrar en members_search (ej. name o segmentado)

    add_index :queries, :source
    add_index :queries, :success
    add_index :queries, :request_id
  end
end