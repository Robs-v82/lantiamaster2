class AddColumnsToCookies < ActiveRecord::Migration[6.0]
	def change
		add_reference :cookies, :quarter, foreign_key: true
		remove_column :cookies, :type
		add_column :cookies, :category, :string
	end
end
