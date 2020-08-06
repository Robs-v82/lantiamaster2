class AddLeagueToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :league, :string
  end
end
