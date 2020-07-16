class ChangeColumnInCities < ActiveRecord::Migration[6.0]
  def change
  	remove_column :cities, :clave, :float
  end
end
