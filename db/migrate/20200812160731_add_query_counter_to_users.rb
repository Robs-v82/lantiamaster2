class AddQueryCounterToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :query_counter, :integer
  end
end
