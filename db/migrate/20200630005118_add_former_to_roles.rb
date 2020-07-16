class AddFormerToRoles < ActiveRecord::Migration[6.0]
  def change
    add_column :roles, :former, :boolean
  end
end
