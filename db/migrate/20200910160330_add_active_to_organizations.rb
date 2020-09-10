class AddActiveToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :active, :boolean
  end
end
