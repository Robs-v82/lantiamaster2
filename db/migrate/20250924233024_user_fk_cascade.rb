class UserFkCascade < ActiveRecord::Migration[6.0]
  TABLES = %i[
    keys
    queries
    subscriptions
    hits
    lrvl_documents
    lrvl_internal_publications
    lrvl_membership_expiration
    lrvl_news
    lrvl_payments
    lrvl_publications
    lrvl_videos
    lrvl_user_conekta_customers
  ]

  def up
    TABLES.each { |t| replace_user_fk(t, on_delete: :cascade) }
  end

  def down
    TABLES.each { |t| replace_user_fk(t, on_delete: :restrict) }
  end

  private

  def replace_user_fk(table, on_delete:)
    return unless table_exists?(table)
    return unless column_exists?(table, :user_id)
    begin
      remove_foreign_key table, :users
    rescue StandardError
      # si no existía FK, seguimos
    end
    add_foreign_key table, :users, column: :user_id, on_delete: on_delete
  end
end


