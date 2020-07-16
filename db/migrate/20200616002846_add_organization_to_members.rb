class AddOrganizationToMembers < ActiveRecord::Migration[6.0]
  def change
    add_reference :members, :organization, foreign_key: true
  end
end
