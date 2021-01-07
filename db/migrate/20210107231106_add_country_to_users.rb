class AddCountryToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :country, :string
    add_column :users, :active, :integer
  end
end
