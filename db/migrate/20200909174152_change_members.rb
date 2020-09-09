class ChangeMembers < ActiveRecord::Migration[6.0]
  def change
  	add_column :members, :alias, :text
  end
end
