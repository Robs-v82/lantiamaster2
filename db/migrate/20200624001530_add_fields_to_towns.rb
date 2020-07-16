class AddFieldsToTowns < ActiveRecord::Migration[6.0]
  def change
  	add_column :towns, :zip_code, :string
  	add_column :towns, :settlement_type, :string
  end
end
