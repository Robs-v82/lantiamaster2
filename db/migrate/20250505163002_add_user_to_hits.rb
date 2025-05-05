class AddUserToHits < ActiveRecord::Migration[6.0]
  def change
    add_reference :hits, :user, foreign_key: true, null: true
  end
end
