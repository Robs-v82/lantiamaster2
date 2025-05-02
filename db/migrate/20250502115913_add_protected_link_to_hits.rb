class AddProtectedLinkToHits < ActiveRecord::Migration[6.0]
  def change
    add_column :hits, :protected_link, :boolean, default: false, null: false
  end
end
