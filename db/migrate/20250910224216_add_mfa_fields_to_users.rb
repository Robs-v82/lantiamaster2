class AddMfaFieldsToUsers < ActiveRecord::Migration[6.0]  # ← ajusta [6.1] a tu versión
  def change
    add_column :users, :mfa_totp_secret, :string
    add_column :users, :mfa_enabled_at, :datetime
    add_column :users, :mfa_backup_codes_digest, :text   # JSON con hashes (BCrypt) de backup codes
    add_column :users, :mfa_last_used_step, :integer     # anti-replay: último time step TOTP aceptado

    add_index  :users, :mfa_enabled_at
  end
end
