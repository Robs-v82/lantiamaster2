class AddEmailVerificationTokenDigestToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :email_verification_token_digest, :string
    add_index :users, :email_verification_token_digest, unique: true
  end
end
