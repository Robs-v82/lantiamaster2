class CreateFakeIdentities < ActiveRecord::Migration[6.0]
  def change
    create_table :fake_identities do |t|
      t.string :firstname
      t.string :lastname1
      t.string :lastname2
      t.references :member, null: false, foreign_key: true

      t.timestamps
    end
  end
end
