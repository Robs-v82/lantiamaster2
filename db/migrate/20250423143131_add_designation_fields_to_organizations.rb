class AddDesignationFieldsToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :designation, :boolean, default: false, null: false
    add_column :organizations, :designation_date, :date
  end
end
