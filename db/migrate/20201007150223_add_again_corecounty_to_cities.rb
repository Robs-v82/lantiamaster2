class AddAgainCorecountyToCities < ActiveRecord::Migration[6.0]
	def change
		add_column :cities, :core_county_id, :integer, index: true
		add_foreign_key :cities, :counties, column: :core_county_id	
	end
end
