class CreateBulkQueryRuns < ActiveRecord::Migration[6.0]
  def change
    create_table :bulk_query_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :csv_filename
      t.jsonb :invalid_rows_data, default: []
      t.jsonb :valid_rows_data, default: []
      t.jsonb :summary_stats, default: {}

      t.timestamps
    end

    add_index :bulk_query_runs, :created_at
  end
end
