class AddDefaultsToUsers < ActiveRecord::Migration[6.0]
	def change
		change_column :users, :victim_help, :boolean, :default => true
		change_column :users, :organization_help, :boolean, :default => true
		change_column :users, :index_help, :boolean, :default => true
	end
end
