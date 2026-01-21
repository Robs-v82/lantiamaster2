class AddEmailVerificationTokenUsedAtToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :email_verification_token_used_at, :datetime
  end
end
