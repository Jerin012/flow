require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Notes User",
      email: "notes@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    @focus_session = @user.focus_sessions.create!(
      subject: "Study",
      topic: "Reading notes",
      energy_level: 3,
      duration_minutes: 20,
      started_at: Time.zone.parse("2026-04-17 09:00:00"),
      ended_at: Time.zone.parse("2026-04-17 09:20:00"),
      deep_work_score: 7.0
    )

    post login_path, params: {
      user: {
        email: @user.email,
        password: "password123"
      }
    }
  end

  test "creates a note for the logged in user" do
    assert_difference("Note.count", 1) do
      post notes_path, params: {
        note: {
          title: "My first note",
          content: "This content should be saved.",
          focus_session_id: @focus_session.id
        }
      }
    end

    note = Note.order(:id).last

    assert_redirected_to note_path(note)
    assert_equal @user.id, note.user_id
    assert_equal @focus_session.id, note.focus_session_id
    assert_equal "My first note", note.title
    assert_equal "This content should be saved.", note.content
  end
end
