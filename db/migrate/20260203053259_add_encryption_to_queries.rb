class AddEncryptionToQueries < ActiveRecord::Migration[6.0]
  def change
    # Lockbox ciphertext columns
    add_column :queries, :firstname_ciphertext, :text
    add_column :queries, :lastname1_ciphertext, :text
    add_column :queries, :lastname2_ciphertext, :text
    add_column :queries, :query_label_ciphertext, :text
    add_column :queries, :outcome_ciphertext, :text

    # Blind index for equality lookup (normalized query_label)
    add_column :queries, :query_label_bidx, :string
    add_index  :queries, :query_label_bidx
  end
end

