class AddDataToCookies < ActiveRecord::Migration[6.0]
  def change
  	add_column :cookies, :data, :text
  end
end
