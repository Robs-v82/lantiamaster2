class RemoveCapitalFromStates < ActiveRecord::Migration[6.0]
  def change
  	remove_column :states, :county_id
  end
end
