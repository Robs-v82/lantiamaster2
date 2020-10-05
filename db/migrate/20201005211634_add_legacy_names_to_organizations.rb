class AddLegacyNamesToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :legacy_names, :string
  end
end
