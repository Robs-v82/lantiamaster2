class AddOfacFieldsToMembers < ActiveRecord::Migration[6.0]
  def change
    add_column :members, :ofac_designation, :boolean
    add_column :members, :ofac_ent_num, :string
    add_column :members, :ofac_last_update, :date
  end
end
