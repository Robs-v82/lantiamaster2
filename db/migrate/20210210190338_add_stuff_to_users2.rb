class AddStuffToUsers2 < ActiveRecord::Migration[6.0]
  def change
  	add_column :users, :promo, :boolean
  	add_column :users, :downloads, :integer, :default => 0
  end
end
