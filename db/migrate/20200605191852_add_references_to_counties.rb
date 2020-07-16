class AddReferencesToCounties < ActiveRecord::Migration[6.0]
  def change
  	add_reference :counties, :city, foreign_key: true
  end
end
