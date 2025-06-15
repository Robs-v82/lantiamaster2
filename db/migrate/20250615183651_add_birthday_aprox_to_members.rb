class AddBirthdayAproxToMembers < ActiveRecord::Migration[6.0]
  def change
    add_column :members, :birthday_aprox, :boolean, default: false
  end
end
