class ChangeMembershipInuUsers < ActiveRecord::Migration[6.0]
  def change
  	# remove_column :users, :membership_id
  	add_column :users, :membership_type, :integer
  end
end
