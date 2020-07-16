class CreateSources < ActiveRecord::Migration[6.0]
  def change
    create_table :sources do |t|
      t.datetime :publication
      t.string :media_type
      t.string :url
      t.references :member, null: false, foreign_key: true
      t.boolean :is_post

      t.timestamps
    end
  end
end
