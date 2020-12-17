class CreateUsersLoginKeys < ActiveRecord::Migration[6.0]
	def change
		create_table :users_login_keys do |t|
			t.references :user, null: false, foreign_key: true
			t.text :key
			t.timestamps
		end
	end
end
