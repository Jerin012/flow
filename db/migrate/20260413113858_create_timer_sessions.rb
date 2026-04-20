class CreateTimerSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :timer_sessions do |t|
      t.string :title
      t.string :title
      t.datetime :start_time
      t.datetime :end_time
      t.integer :total_focus_ms
      t.integer :total_away_ms

      t.timestamps
    end
  end
end
