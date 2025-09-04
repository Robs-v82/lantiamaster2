class AddLoginLockToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :failed_login_attempts, :integer, default: 0, null: false
    add_column :users, :locked_until, :datetime
    add_index  :users, :locked_until
  end
end

