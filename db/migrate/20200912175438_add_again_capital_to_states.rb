class AddAgainCapitalToStates < ActiveRecord::Migration[6.0]
	def change
		add_column :states, :capital_id, :integer, index: true
		add_foreign_key :states, :counties, column: :capital_id
	end
end
