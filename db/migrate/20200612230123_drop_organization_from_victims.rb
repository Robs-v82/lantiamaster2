class DropOrganizationFromVictims < ActiveRecord::Migration[6.0]
  def change
  	remove_reference(:victims, :organization, index: true, null: false, foreign_key: true)
  end
end
