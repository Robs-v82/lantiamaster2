class AddHelpToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :victim_help, :boolean
  end
end
