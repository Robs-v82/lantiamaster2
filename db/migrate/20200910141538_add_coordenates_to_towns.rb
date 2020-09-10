class AddCoordenatesToTowns < ActiveRecord::Migration[6.0]
  def change
    add_column :towns, :latitude, :float
    add_column :towns, :longitude, :float
  end
end
