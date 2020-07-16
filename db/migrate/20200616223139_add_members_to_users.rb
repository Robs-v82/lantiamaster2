class AddMembersToUsers < ActiveRecord::Migration[6.0]
  def change
    add_reference :users, :member, foreign_key: true
    remove_column :users, :firstname
    remove_column :users, :lastname1
    remove_column :users, :lastname2
  end
end
