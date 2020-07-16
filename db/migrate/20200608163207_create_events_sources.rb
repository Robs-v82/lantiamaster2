class CreateEventsSources < ActiveRecord::Migration[6.0]
  def change
    create_table :events_sources, :id => false do |t|
      t.integer :event_id
      t.integer :source_id

    end
  end
end
