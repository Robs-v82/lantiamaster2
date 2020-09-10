class CreateOrganizationTowns < ActiveRecord::Migration[6.0]
	def change
		create_table :organization_towns do |t|
			t.belongs_to :town
			t.belongs_to :organization
		end
	end
end
