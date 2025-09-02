class CreatePlansAndSubscriptions < ActiveRecord::Migration[6.0]
  def change
    create_table :plans do |t|
      t.string  :name, null: false
      t.integer :level, null: false              # mismo número que membership_id de Laravel
      t.integer :duration_days, null: false, default: 30
      t.timestamps
      t.index :level, unique: true
    end

    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :plan, null: false, foreign_key: true
      t.datetime :current_period_end, null: false
      t.string   :status, null: false, default: "active"   # active|canceled|past_due
      t.timestamps
      t.index [:user_id, :status]
    end
  end
end

