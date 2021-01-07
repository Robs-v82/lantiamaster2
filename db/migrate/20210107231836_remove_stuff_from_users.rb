class RemoveStuffFromUsers < ActiveRecord::Migration[6.0]
  def change
  	remove_column :users, :active
	add_column :users, :active, :integer, :default => 1
  end
end
