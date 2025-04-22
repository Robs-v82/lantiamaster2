class CreateQueries < ActiveRecord::Migration[6.0]
  def change
    create_table :queries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.float :homo_score
      t.string :firstname
      t.string :lastname1
      t.string :lastname2
      t.text :outcome
      t.integer :search

      t.timestamps
    end
  end
end
