class CreateNames < ActiveRecord::Migration[6.0]
  def change
    create_table :names do |t|
      t.string :word
      t.integer :freq

      t.timestamps
    end
  end
end
