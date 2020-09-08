class AddColumnsToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :subleague, :string
    add_column :organizations, :legacy_id, :integer
  end
end
