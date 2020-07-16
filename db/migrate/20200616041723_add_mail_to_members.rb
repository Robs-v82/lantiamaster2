class AddMailToMembers < ActiveRecord::Migration[6.0]
  def change
    add_column :members, :mail, :string
  end
end
