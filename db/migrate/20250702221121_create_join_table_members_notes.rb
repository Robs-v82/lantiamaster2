class CreateJoinTableMembersNotes < ActiveRecord::Migration[6.0]
  def change
    create_join_table :members, :notes do |t|
      # t.index [:member_id, :note_id]
      # t.index [:note_id, :member_id]
    end
  end
end
