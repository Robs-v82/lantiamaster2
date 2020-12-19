class ChangeStuffInKeys < ActiveRecord::Migration[6.0]
	def change
		change_column :keys, :user_id, :integer, limit: 8
		remove_column :keys, :integer
	end
end
