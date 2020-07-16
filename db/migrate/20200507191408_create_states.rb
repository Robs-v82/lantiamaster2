class CreateStates < ActiveRecord::Migration[6.0]
  def change
    create_table :states do |t|
      t.string :name
      t.string :shortname
      t.string :code
      t.integer :population

      t.timestamps
    end
  end
end
