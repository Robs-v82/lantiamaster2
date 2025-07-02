class AddRoleGendersToMemberRelationships < ActiveRecord::Migration[6.0]
  def change
    add_column :member_relationships, :role_a_gender, :string
    add_column :member_relationships, :role_b_gender, :string
  end
end
