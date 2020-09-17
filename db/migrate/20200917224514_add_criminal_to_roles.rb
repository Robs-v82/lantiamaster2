class AddCriminalToRoles < ActiveRecord::Migration[6.0]
  def change
    add_column :roles, :criminal, :boolean
  end
end
