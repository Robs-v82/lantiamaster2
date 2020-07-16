class AddFullCodeToCounties < ActiveRecord::Migration[6.0]
  def change
  	  		add_column :counties, :full_code, :string
  end
end
