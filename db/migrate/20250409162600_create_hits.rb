class CreateHits < ActiveRecord::Migration[6.0]
  def change
    create_table :hits do |t|
      t.date :date
      t.string :title
      t.string :link
      t.references :town, null: false, foreign_key: true

      t.timestamps
    end
  end
end
