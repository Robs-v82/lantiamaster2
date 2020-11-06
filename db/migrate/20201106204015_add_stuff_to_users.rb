class AddStuffToUsers < ActiveRecord::Migration[6.0]
  def change
  	add_column :users, :remember_token, :string
  	add_column :users, :email_verified_at, :datetime
  	add_column :users, :role_id, :integer
  end
end
