class FocusSession < ApplicationRecord
  belongs_to :user
  has_many :notes, dependent: :nullify
  enum :status, {
    draft: "draft",
    active: "active",
    paused: "paused",
    completed: "completed",
    abandoned: "abandoned"
  }, default: :draft, validate: true

  scope :in_progress, -> { where(status: %w[active paused]) }

  def persisted_timer_state
    raw_state = session_data.presence || "{}"
    JSON.parse(raw_state)
  rescue JSON::ParserError
    {}
  end

  def timer_resume_payload
    return {} unless active? || paused?

    {
      status: status,
      started_at: started_at&.iso8601,
      last_synced_at: last_synced_at&.iso8601,
      planned_duration_minutes: planned_duration_minutes,
      state: persisted_timer_state
    }
  end
end
