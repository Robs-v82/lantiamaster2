class RemoveCoreFromCounties < ActiveRecord::Migration[6.0]
  def change
   def change
  		remove_column :cities, :county_id
  	end
  end
end
