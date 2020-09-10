class CreateTownsAndOrganization < ActiveRecord::Migration[6.0]
	def change
		create_table :towns_and_organizations do |t|
			t.belongs_to :town
			t.belongs_to :organization
		end
	end
end
