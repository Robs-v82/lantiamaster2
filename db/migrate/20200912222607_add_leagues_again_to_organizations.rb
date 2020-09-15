class AddLeaguesAgainToOrganizations < ActiveRecord::Migration[6.0]
	def change
		add_column :organizations, :mainleague_id, :integer, index: true
		add_foreign_key :organizations, :leagues, column: :mainleague_id
	end
end
