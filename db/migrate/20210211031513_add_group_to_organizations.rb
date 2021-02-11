class AddGroupToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :group, :string
  end
end
