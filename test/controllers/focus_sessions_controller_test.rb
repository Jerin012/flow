require "test_helper"

class FocusSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Focus User",
      email: "focus@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post login_path, params: {
      user: {
        email: @user.email,
        password: "password123"
      }
    }
  end

  test "dashboard is the logged in root" do
    get root_path

    assert_response :success
    assert_match "Dashboard", @response.body
  end

  test "creates a focus session and redirects to activity tracking" do
    assert_difference("FocusSession.count", 1) do
      post focus_sessions_path, params: {
        focus_session: {
          subject: "Engineering & Coding",
          topic: "Implement dashboard",
          energy_level: 4
        }
      }
    end

    session = FocusSession.order(:id).last

    assert_redirected_to activity_tracking_path(focus_session_id: session.id)
    assert_equal @user.id, session.user_id
    assert_equal "draft", session.status
  end

  test "activates and syncs timer state for resume flow" do
    focus_session = @user.focus_sessions.create!(
      subject: "Engineering & Coding",
      topic: "Persistence test",
      energy_level: 4
    )

    patch activate_focus_session_path(focus_session), params: {
      timer: {
        started_at: Time.current.iso8601,
        planned_duration_minutes: 25,
        elapsed_focus_ms: 60_000,
        elapsed_break_ms: 0,
        state: { total_ms: 1_500_000, remaining_ms: 1_440_000, focus_ms: 60_000, absence_log: [] }.to_json
      }
    }, as: :json

    assert_response :success
    assert_equal "active", focus_session.reload.status

    patch sync_state_focus_session_path(focus_session), params: {
      timer: {
        status: "paused",
        started_at: focus_session.started_at.iso8601,
        planned_duration_minutes: 25,
        elapsed_focus_ms: 120_000,
        elapsed_break_ms: 30_000,
        state: { total_ms: 1_500_000, remaining_ms: 1_350_000, focus_ms: 120_000, absence_log: [{ type: "break", durationMs: 30_000 }] }.to_json
      }
    }, as: :json

    assert_response :success

    focus_session.reload
    assert_equal "paused", focus_session.status
    assert_equal 120_000, focus_session.elapsed_focus_ms
    assert_equal 30_000, focus_session.elapsed_break_ms
  end
end
