class CreateDetentionsOrganizations < ActiveRecord::Migration[6.0]
	def change
		create_table :detentions_organizations do |t|
			t.belongs_to :detention
			t.belongs_to :organization
		end
	end
end
