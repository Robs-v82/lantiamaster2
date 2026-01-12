class MakeDataAccessNullableInOrganizations < ActiveRecord::Migration[6.0]
  def change
    change_column_null :organizations, :data_access, true
    change_column_default :organizations, :data_access, from: false, to: nil
  end
end