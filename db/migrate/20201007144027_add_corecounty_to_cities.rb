class AddCorecountyToCities < ActiveRecord::Migration[6.0]
  def change
    add_reference :cities, :county, foreign_key: true
  end
end
