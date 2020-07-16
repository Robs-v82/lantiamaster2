class AddColumnsToUsers < ActiveRecord::Migration[6.0]
  def change
  	def change
  		add_column :users, :organizarion, :references
  		add_column :users, :role, :references
  	end
  end
end
