class CreateAuthEvents < ActiveRecord::Migration[6.0]
  def change
    create_table :auth_events do |t|
      t.integer :user_id
      t.string  :event_type, null: false   # login_success, login_failure, logout, reset_request, reset_success, reauth_success, lockout
      t.string  :ip
      t.text    :user_agent
      t.text    :metadata                   # JSON serializado
      t.timestamps
    end
    add_index :auth_events, :user_id
    add_index :auth_events, :event_type
    add_index :auth_events, :created_at
  end
end
