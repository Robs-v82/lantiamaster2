class AddShortnameToCounties < ActiveRecord::Migration[6.0]
  def change
    add_column :counties, :shortname, :string
  end
end
