class AddDetentionToMembers < ActiveRecord::Migration[6.0]
  def change
    add_reference :members, :detention, foreign_key: true
  end
end
