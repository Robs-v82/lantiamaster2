class AddLeaguesToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_reference :organizations, :league, foreign_key: true
  end
end
