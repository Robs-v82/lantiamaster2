class DropColumnFromOrganizations < ActiveRecord::Migration[6.0]
	def change
		remove_column :organizations, :league_id		
	end
end
