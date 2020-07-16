class DropMemberFromSources < ActiveRecord::Migration[6.0]
  def change
  	remove_column :sources, :member_id
  end
end
