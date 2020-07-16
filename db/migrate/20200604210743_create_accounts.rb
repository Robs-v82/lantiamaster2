class CreateAccounts < ActiveRecord::Migration[6.0]
  def change
    create_table :accounts do |t|
      t.integer :code
      t.string :name
      t.string :network

      t.timestamps
    end
  end
end
