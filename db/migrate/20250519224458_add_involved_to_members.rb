class AddInvolvedToMembers < ActiveRecord::Migration[6.0]
  def change
    add_column :members, :involved, :boolean
  end
end
