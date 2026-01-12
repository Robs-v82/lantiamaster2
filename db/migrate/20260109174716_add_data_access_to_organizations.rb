class AddDataAccessToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :data_access, :boolean, default: false, null: false
  end
end
