class CreateDuplicationLogs < ActiveRecord::Migration[6.0]
  def change
    create_table :duplication_logs do |t|
      t.references :source_record, foreign_key: { to_table: :detention_captures }, optional: true
      t.references :duplicate_record, foreign_key: { to_table: :detention_captures }
      t.string :action, null: false
      t.string :reason
      t.references :user, foreign_key: true, optional: true
      t.text :notes

      t.timestamps
    end

    add_index :duplication_logs, :action
    add_index :duplication_logs, :reason
    add_index :duplication_logs, :created_at
  end
end
