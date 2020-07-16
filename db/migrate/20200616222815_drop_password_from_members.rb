class DropPasswordFromMembers < ActiveRecord::Migration[6.0]
  def change
  	remove_column :members, :password_digest
  	remove_column :members, :recovery_password_digest
  end
end
