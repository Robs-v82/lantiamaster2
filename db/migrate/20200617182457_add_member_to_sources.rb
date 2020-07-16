class AddMemberToSources < ActiveRecord::Migration[6.0]
  def change
    add_reference :sources, :member, foreign_key: true
  end
end
