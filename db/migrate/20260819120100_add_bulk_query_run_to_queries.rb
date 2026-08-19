class AddBulkQueryRunToQueries < ActiveRecord::Migration[6.0]
  def change
    add_reference :queries, :bulk_query_run, foreign_key: true, null: true
  end
end
