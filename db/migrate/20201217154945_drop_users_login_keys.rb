class DropUsersLoginKeys < ActiveRecord::Migration[6.0]
	def change
		drop_table :users_login_keys
	end
end
