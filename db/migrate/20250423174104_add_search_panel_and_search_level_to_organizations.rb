class AddSearchPanelAndSearchLevelToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :search_panel, :boolean, default: false, null: false
    add_column :organizations, :search_level, :integer
  end
end
