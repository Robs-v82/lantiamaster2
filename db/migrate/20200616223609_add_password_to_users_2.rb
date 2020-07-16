class AddPasswordToUsers2 < ActiveRecord::Migration[6.0]
  def change
  	add_column :users, :password_digest, :string
 	add_column :users, :recovery_password_digest, :string
  end
end
