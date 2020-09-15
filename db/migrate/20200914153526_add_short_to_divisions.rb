class AddShortToDivisions < ActiveRecord::Migration[6.0]
  def change
    add_column :divisions, :shortname, :string
  end
end
