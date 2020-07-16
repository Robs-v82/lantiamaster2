class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :firstname
      t.string :lastname1
      t.string :lastname2
      t.string :mail
      t.integer :mobile_phone
      t.integer :other_phone
      t.string :password_digest
      t.timestamps
    end
  end
end
