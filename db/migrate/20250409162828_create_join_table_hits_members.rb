class CreateJoinTableHitsMembers < ActiveRecord::Migration[6.0]
  def change
    create_join_table :hits, :members do |t|
      t.index [:hit_id, :member_id]
      t.index [:member_id, :hit_id]
    end
  end
end
