class ChangeOrganizationOrigin < ActiveRecord::Migration[6.0]
  def change
  	remove_column :organizations, :origin_id
  	add_column :organizations, :origin, :text
  end
end
