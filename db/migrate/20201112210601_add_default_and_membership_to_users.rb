class AddDefaultAndMembershipToUsers < ActiveRecord::Migration[6.0]
	def change
		change_column :users, :role_id, :integer, :default => 2
		add_column :users, :membership_id, :integer
	end
end
