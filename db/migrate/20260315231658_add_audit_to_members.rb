class AddAuditToMembers < ActiveRecord::Migration[6.0]
  def change
    add_column :members, :audit, :boolean, default: false
  end
end
