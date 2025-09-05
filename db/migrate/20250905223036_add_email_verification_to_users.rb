class AddEmailVerificationToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :email_verification_digest, :string
    add_column :users, :email_verification_sent_at, :datetime
    add_index  :users, :email_verification_digest
  end
end
