require "test_helper"

class ActivityTracksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Activity User",
      email: "activity@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    @focus_session = @user.focus_sessions.create!(
      subject: "Build feature",
      topic: "Track persistence",
      energy_level: 4,
      duration_minutes: 25,
      started_at: Time.zone.parse("2026-04-17 10:00:00"),
      ended_at: Time.zone.parse("2026-04-17 10:25:00"),
      deep_work_score: 8.5
    )

    post login_path, params: {
      user: {
        email: @user.email,
        password: "password123"
      }
    }
  end

  test "creates an activity track with the persisted session fields" do
    start_time = Time.zone.parse("2026-04-17 11:00:00")
    end_time = Time.zone.parse("2026-04-17 11:25:00")
    payload = { absenceLog: [{ type: "work", durationMs: 12000 }] }.to_json

    assert_difference("ActivityTrack.count", 1) do
      post activity_tracking_path, params: {
        focus_session_id: @focus_session.id,
        activity_track: {
          title: "Manual fallback title",
          duration_minutes: 25,
          start_time: start_time.iso8601,
          end_time: end_time.iso8601,
          total_focus_ms: 1_500_000,
          session_data: payload
        }
      }
    end

    activity_track = ActivityTrack.order(:id).last

    assert_redirected_to activity_track_path(activity_track)
    assert_equal @user.id, activity_track.user_id
    assert_equal @focus_session.topic, activity_track.title
    assert_equal 25, activity_track.duration_minutes
    assert_equal start_time.to_i, activity_track.start_time.to_i
    assert_equal end_time.to_i, activity_track.end_time.to_i
    assert_equal 1_500_000, activity_track.total_focus_ms
    assert_equal payload, activity_track.session_data
  end
end
