class AddEnsuCitiesToStates < ActiveRecord::Migration[6.0]
  def change
  	add_column :states, :ensu_cities, :text
  end
end
