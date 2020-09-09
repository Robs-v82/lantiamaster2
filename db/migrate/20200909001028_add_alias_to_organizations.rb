class AddAliasToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :alias, :text
  end
end
