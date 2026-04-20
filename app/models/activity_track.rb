class ActivityTrack < ApplicationRecord
  belongs_to :user

  before_validation :normalize_session_data

  validates :title, presence: true
  validates :duration_minutes, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :total_focus_ms, presence: true
  validates :session_data, presence: true
  validate :session_data_must_be_valid_json

  def total_focus_minutes
    total_focus_ms.to_f / 60000
  end

  def parsed_session_data
    JSON.parse(session_data.presence || "{}", symbolize_names: true)
  rescue JSON::ParserError
    {}
  end

  private

  def normalize_session_data
    self.session_data = "{}" if session_data.blank?
    self.session_data = session_data.to_json if session_data.is_a?(Hash) || session_data.is_a?(Array)
  end

  def session_data_must_be_valid_json
    JSON.parse(session_data.to_s)
  rescue JSON::ParserError
    errors.add(:session_data, "must be valid JSON")
  end
end
