class AddAccessToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :victim_access, :boolean, :default => true
    add_column :users, :organization_access, :boolean, :default => true
    add_column :users, :detention_access, :boolean, :default => true
    add_column :users, :irco_access, :boolean, :default => true
    add_column :users, :icon_access, :boolean, :default => true
  end
end
