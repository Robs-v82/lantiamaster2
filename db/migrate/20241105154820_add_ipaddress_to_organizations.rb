class AddIpaddressToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :ip_address, :text
  end
end
