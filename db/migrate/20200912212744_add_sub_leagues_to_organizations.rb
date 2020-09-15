class AddSubLeaguesToOrganizations < ActiveRecord::Migration[6.0]
	def change
		add_column :organizations, :subleague_id, :integer, index: true
		add_foreign_key :organizations, :leagues, column: :subleague_id
	end
end
