class CreatePosts < ActiveRecord::Migration[6.0]
  def change
    create_table :posts do |t|
      t.datetime :publication
      t.string :content
      t.string :hashtags
      t.integer :likes
      t.integer :shares
      t.boolean :is_quote
      t.boolean :is_retweet
      t.string :url
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
  end
end
