class AddLegacyToVictims < ActiveRecord::Migration[6.0]
  def change
	add_column :victims, :legacy_name, :string
  end
end
