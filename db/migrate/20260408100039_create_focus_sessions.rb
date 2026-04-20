class CreateFocusSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :focus_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :subject
      t.string :topic
      t.integer :energy_level
      t.integer :duration_minutes
      t.datetime :started_at
      t.datetime :ended_at
      t.float :deep_work_score

      t.timestamps
    end
  end
end
