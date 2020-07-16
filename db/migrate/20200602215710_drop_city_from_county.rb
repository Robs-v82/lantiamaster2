class DropCityFromCounty < ActiveRecord::Migration[6.0]
  def change
  	      remove_column :counties, :city_id
  end
end
