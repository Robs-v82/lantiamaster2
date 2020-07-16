class CreateKillings < ActiveRecord::Migration[6.0]
  def change
    create_table :killings do |t|
      t.integer :legacy_id
      t.integer :killed_count
      t.integer :wounded_count
      t.integer :killers_count
      t.integer :arrested_count
      t.string :type_of_place
      t.boolean :mass_grave
      t.boolean :fire_weapon
      t.boolean :white_weapon
      t.boolean :aggression
      t.boolean :shooting_between_criminals_and_authorities
      t.string :notes
      t.references :event, null: false, foreign_key: true

      t.timestamps
    end
  end
end
