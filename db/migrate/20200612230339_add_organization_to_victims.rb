class AddOrganizationToVictims < ActiveRecord::Migration[6.0]
  def change
    add_reference :victims, :organization, foreign_key: true
  end
end
