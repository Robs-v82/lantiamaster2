class CreateDetentionsMonthlyExports < ActiveRecord::Migration[6.0]
  def change
    create_table :detentions_monthly_exports do |t|
      t.integer :year, null: false
      t.integer :month, null: false
      t.date :capture_start_date
      t.date :capture_end_date
      t.integer :total_captures, default: 0
      t.integer :duplicates_removed, default: 0
      t.integer :final_unique_incidents, default: 0
      t.datetime :validation_completed_at
      t.string :csv_file_path
      t.string :status, default: 'pending_validation'
      t.datetime :uploaded_to_final_system_at
      t.text :validation_notes

      t.timestamps
    end

    add_index :detentions_monthly_exports, [:year, :month], unique: true
    add_index :detentions_monthly_exports, :status
  end
end
