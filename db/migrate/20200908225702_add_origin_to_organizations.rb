class AddOriginToOrganizations < ActiveRecord::Migration[6.0]
	def change
		add_column :organizations, :origin_id, :integer, index: true
		add_foreign_key :organizations, :organizations, column: :origin_id
	end
end
