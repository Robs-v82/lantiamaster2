class ChangeVictimGenderToString < ActiveRecord::Migration[6.0]
  def change
  	change_column :victims, :gender, :string
  end
end
