class AddMediaScoreToMembers < ActiveRecord::Migration[6.0]
  def change
    add_column :members, :media_score, :boolean
  end
end
