class AddSessionVersionToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :session_version, :string
    add_index  :users, :session_version
  end
end
