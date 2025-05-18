class AddCriminalLinkToMembers < ActiveRecord::Migration[6.0]
  def change
    add_column :members, :criminal_link_id, :integer
  end
end
