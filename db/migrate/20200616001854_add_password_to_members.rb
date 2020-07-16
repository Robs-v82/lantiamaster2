class AddPasswordToMembers < ActiveRecord::Migration[6.0]
  def change
  	remove_column :members, :organization_id
  	remove_column :members, :role_id
 	add_column :members, :password_digest, :string
 	add_column :members, :recovery_password_digest, :string
  end
end
