class AddMemberAddedToDetentionCaptures < ActiveRecord::Migration[6.0]
  def change
    add_column :detention_captures, :member_added, :boolean, default: false
  end
end
