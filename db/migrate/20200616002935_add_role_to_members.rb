class AddRoleToMembers < ActiveRecord::Migration[6.0]
  def change
    add_reference :members, :role, foreign_key: true
  end
end
