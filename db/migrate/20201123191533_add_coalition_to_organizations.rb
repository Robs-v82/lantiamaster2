class AddCoalitionToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_column :organizations, :coalition, :string
    add_column :organizations, :color, :string
  end
end
