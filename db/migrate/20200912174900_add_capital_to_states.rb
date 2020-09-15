class AddCapitalToStates < ActiveRecord::Migration[6.0]
  def change
    add_reference :states, :county, foreign_key: true
  end
end
