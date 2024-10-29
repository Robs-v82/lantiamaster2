class AddIpaddressToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :ip_address, :string
  end
end
