class CreateOfacCandidates < ActiveRecord::Migration[6.0]
  def change
    create_table :ofac_candidates do |t|
      t.string :ofac_name, null: false
      t.integer :status, default: 0
      t.references :organization, null: true, foreign_key: true
      t.integer :search_attempts, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :ofac_candidates, :ofac_name, unique: true
  end
end
