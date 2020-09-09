class AddStuffToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :allies, :text
    add_column :organizations, :rivals, :text
  end
end
