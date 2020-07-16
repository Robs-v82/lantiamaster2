class AddCountyToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_reference :organizations, :county, foreign_key: true
  end
end
