class AddSessionStateToFocusSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :focus_sessions, :status, :string, null: false, default: "draft"
    add_column :focus_sessions, :planned_duration_minutes, :integer
    add_column :focus_sessions, :elapsed_focus_ms, :bigint, null: false, default: 0
    add_column :focus_sessions, :elapsed_break_ms, :bigint, null: false, default: 0
    add_column :focus_sessions, :last_synced_at, :datetime
    add_column :focus_sessions, :session_data, :text

    add_index :focus_sessions, :status
  end
end
