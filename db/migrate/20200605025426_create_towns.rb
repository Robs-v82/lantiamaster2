class CreateTowns < ActiveRecord::Migration[6.0]
  def change
    create_table :towns do |t|
      t.string :code
      t.string :full_code
      t.string :name
      t.references :county, null: false, foreign_key: true
      t.string :type
      t.integer :population
      t.integer :height

      t.timestamps
    end
  end
end
