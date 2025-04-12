class AddEventsToMembers < ActiveRecord::Migration[6.0]
  def change
    add_reference :members, :member, null: true, foreign_key: true
  end
end
