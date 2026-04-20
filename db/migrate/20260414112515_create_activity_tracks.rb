class CreateActivityTracks < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_tracks do |t|
      t.string :title
      t.integer :duration_minutes
      t.datetime :start_time
      t.datetime :end_time
      t.bigint :total_focus_ms
      t.json :session_data

      t.timestamps
    end
  end
end
