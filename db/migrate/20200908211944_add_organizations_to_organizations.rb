class AddOrganizationsToOrganizations < ActiveRecord::Migration[6.0]
	def change
		add_column :organizations, :parent_id, :integer, index: true
		add_foreign_key :organizations, :organizations, column: :parent_id
	end
end
