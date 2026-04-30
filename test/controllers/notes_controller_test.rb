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

    assert_redirected_to notes_path
    assert_equal @user.id, note.user_id
    assert_equal @focus_session.id, note.focus_session_id
    assert_equal "My first note", note.title
    assert_equal "This content should be saved.", note.content
  end

  test "updates a note and returns to all notes" do
    note = @user.notes.create!(
      title: "Draft note",
      content: "Before edit.",
      focus_session: @focus_session
    )

    patch note_path(note), params: {
      note: {
        title: "Updated note",
        content: "After edit.",
        focus_session_id: @focus_session.id
      }
    }

    assert_redirected_to notes_path
    assert_equal "Updated note", note.reload.title
    assert_equal "After edit.", note.content
  end

  test "soft deletes a note into recycle bin" do
    note = @user.notes.create!(
      title: "Disposable note",
      content: "Delete me later.",
      focus_session: @focus_session
    )

    assert_no_difference("Note.count") do
      delete note_path(note)
    end

    assert_redirected_to recycle_bin_notes_path
    assert note.reload.deleted?
  end

  test "restore returns a deleted note to active notes" do
    note = @user.notes.create!(
      title: "Bring me back",
      content: "Restore this note.",
      focus_session: @focus_session,
      deleted_at: Time.current
    )

    patch restore_note_path(note)

    assert_redirected_to notes_path
    assert_nil note.reload.deleted_at
  end

  test "permanently deletes a note from recycle bin" do
    note = @user.notes.create!(
      title: "Remove forever",
      content: "No coming back.",
      focus_session: @focus_session,
      deleted_at: Time.current
    )

    assert_difference("Note.count", -1) do
      delete destroy_forever_note_path(note)
    end

    assert_redirected_to recycle_bin_notes_path
  end
end
