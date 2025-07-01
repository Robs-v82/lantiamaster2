class CreateTitles < ActiveRecord::Migration[6.0]
  def change
    create_table :titles do |t|
      t.string :legacy_id
      t.string :type
      t.string :profesion
      t.references :member, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :year, null: false, foreign_key: true

      t.timestamps
    end
  end
end
