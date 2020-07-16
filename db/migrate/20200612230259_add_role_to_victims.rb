class AddRoleToVictims < ActiveRecord::Migration[6.0]
  def change
    add_reference :victims, :role, foreign_key: true
  end
end
