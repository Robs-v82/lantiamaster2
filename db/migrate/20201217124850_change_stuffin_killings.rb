class ChangeStuffinKillings < ActiveRecord::Migration[6.0]
	def change
		change_column :killings, :legacy_number, :integer, limit: 8
	end
end
