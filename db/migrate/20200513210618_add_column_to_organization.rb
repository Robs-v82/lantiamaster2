class AddColumnToOrganization < ActiveRecord::Migration[6.0]
  def change
  		 add_column :organizations, :rfc, :string
  end
end
