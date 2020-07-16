class AddLegacyRoleToVictims < ActiveRecord::Migration[6.0]
  def change
  	add_column :victims, :legacy_role_officer, :string
  	add_column :victims, :legacy_role_civil, :string
  end
end
