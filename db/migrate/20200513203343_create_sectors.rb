class CreateSectors < ActiveRecord::Migration[6.0]
  def change
    create_table :sectors do |t|
      t.string :name
      t.string :description
      t.integer :scian2

      t.timestamps
    end
  end
end
