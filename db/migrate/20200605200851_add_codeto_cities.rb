class AddCodetoCities < ActiveRecord::Migration[6.0]
  def change
   	add_column :cities, :code, :string
  end
end
