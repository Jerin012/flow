class NotesController < ApplicationController
  before_action :require_login
  before_action :set_note, only: %i[show edit update destroy]
  before_action :set_deleted_note, only: %i[restore destroy_forever]

  def index
    @notes = current_user.notes.active.includes(:focus_session).order(updated_at: :desc)
  end

  def recycle_bin
    @deleted_notes = current_user.notes.deleted.includes(:focus_session).order(deleted_at: :desc, updated_at: :desc)
  end

  def show
  end

  def focus_session_note
    focus_session = current_user.focus_sessions.find(params[:focus_session_id])
    existing_note = session_note_for(focus_session)

    if existing_note
      redirect_to edit_note_path(existing_note, return_to: timer_return_path(focus_session))
    else
      redirect_to new_note_path(focus_session_id: focus_session.id, return_to: timer_return_path(focus_session))
    end
  end

  def new
    @focus_session = current_user.focus_sessions.find_by(id: params[:focus_session_id])
    existing_note = session_note_for(@focus_session)
    return redirect_to(edit_note_path(existing_note, return_to: timer_return_path(@focus_session))) if existing_note

    @note = current_user.notes.new(
      focus_session: @focus_session,
      title: default_title_for(@focus_session)
    )
    @return_to = timer_return_path(@focus_session)
  end

  def create
    @note = current_user.notes.new(note_params)
    @return_to = timer_return_path(@note.focus_session)

    respond_to do |format|
      if @note.save
        format.html { redirect_after_save(format, @note, "Note saved successfully.") }
        format.json { render json: { message: "Note saved successfully.", note_id: @note.id }, status: :created }
      else
        @focus_session = current_user.focus_sessions.find_by(id: params.dig(:note, :focus_session_id))
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @note.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @return_to = timer_return_path(@note.focus_session)
  end

  def update
    @return_to = timer_return_path(@note.focus_session)

    if @note.update(note_params)
      redirect_after_save(nil, @note, "Note updated successfully.")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @note.update!(deleted_at: Time.current)
    redirect_to recycle_bin_notes_path, notice: "Note moved to Recycle Bin."
  end

  def restore
    @note.update!(deleted_at: nil)
    redirect_to notes_path, notice: "Note restored successfully."
  end

  def destroy_forever
    @note.destroy!
    redirect_to recycle_bin_notes_path, notice: "Note permanently deleted."
  end

  private

  def set_note
    @note = current_user.notes.active.find(params[:id])
  end

  def set_deleted_note
    @note = current_user.notes.deleted.find(params[:id])
  end

  def note_params
    params.require(:note).permit(:title, :content, :focus_session_id)
  end

  def redirect_after_save(_format, note, message)
    if @return_to.present?
      redirect_to edit_note_path(note, return_to: @return_to), notice: message
    else
      redirect_to notes_path, notice: message
    end
  end

  def safe_return_to
    path = params[:return_to].to_s
    path.start_with?("/") ? path : nil
  end

  def timer_return_path(focus_session)
    safe_return_to || (focus_session ? activity_tracking_path(focus_session_id: focus_session.id) : nil)
  end

  def session_note_for(focus_session)
    return unless focus_session

    current_user.notes.active.where(focus_session: focus_session).order(updated_at: :desc).first
  end

  def default_title_for(focus_session)
    return "Session note" unless focus_session&.topic.present?

    "Note for #{focus_session.topic}"
  end
end
