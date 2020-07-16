class DropRoleFromVictims < ActiveRecord::Migration[6.0]
  def change
  	remove_reference(:victims, :role, index: true, null: false, foreign_key: true)
  end
end
