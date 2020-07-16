class CreateDivisions < ActiveRecord::Migration[6.0]
  def change
    create_table :divisions do |t|
      t.string :name
      t.string :description
      t.integer :scian3
      t.references :sector, null: false, foreign_key: true

      t.timestamps
    end
  end
end
