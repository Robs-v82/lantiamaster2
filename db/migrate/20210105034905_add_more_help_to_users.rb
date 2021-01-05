class AddMoreHelpToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :organization_help, :boolean
    add_column :users, :index_help, :boolean
  end
end
