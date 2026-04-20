class NotesController < ApplicationController
  before_action :require_login
  before_action :set_note, only: %i[show edit update]

  def index
    @notes = current_user.notes.includes(:focus_session).order(updated_at: :desc)
  end

  def show
  end

  def new
    @focus_session = current_user.focus_sessions.find_by(id: params[:focus_session_id])
    @note = current_user.notes.new(
      focus_session: @focus_session,
      title: default_title_for(@focus_session)
    )
  end

  def create
    @note = current_user.notes.new(note_params)

    if @note.save
      redirect_to @note, notice: "Note saved successfully."
    else
      @focus_session = current_user.focus_sessions.find_by(id: params.dig(:note, :focus_session_id))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @note.update(note_params)
      redirect_to @note, notice: "Note updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_note
    @note = current_user.notes.find(params[:id])
  end

  def note_params
    params.require(:note).permit(:title, :content, :focus_session_id)
  end

  def default_title_for(focus_session)
    return "Session note" unless focus_session&.topic.present?

    "Note for #{focus_session.topic}"
  end
end
