class ChangeNumbersInUsers < ActiveRecord::Migration[6.0]
	def change
		change_column :users, :mobile_phone, :string
		change_column :users, :other_phone, :string
	end
end
