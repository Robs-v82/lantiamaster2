class CreateMembers < ActiveRecord::Migration[6.0]
  def change
    create_table :members do |t|
      t.string :firstname
      t.string :lastname1
      t.string :lastname2
      t.string :rfc
      t.date :birthday
      t.references :organization, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.string :gender

      t.timestamps
    end
  end
end
