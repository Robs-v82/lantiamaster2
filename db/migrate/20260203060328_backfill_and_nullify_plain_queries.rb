class BackfillAndNullifyPlainQueries < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    # Backfill moved to a post-deploy task to avoid requiring Lockbox during deploy.
  end

  def down
    # No reversible
  end
end

