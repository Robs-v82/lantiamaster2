class AddActivelinksAndActivesinceToOrganizations < ActiveRecord::Migration[6.0]
  def change
  	add_column :organizations, :active_links, :boolean
  	add_column :organizations, :active_since, :date
  end
end
