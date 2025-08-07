class AddCriminalLinkToOrganizations < ActiveRecord::Migration[6.0]
  def change
    add_reference :organizations, :criminal_link, foreign_key: { to_table: :organizations }, null: true
  end
end

