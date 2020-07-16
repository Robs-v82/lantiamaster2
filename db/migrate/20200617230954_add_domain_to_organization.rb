class AddDomainToOrganization < ActiveRecord::Migration[6.0]
  def change
  	add_column :organizations, :domain, :string
  end
end
