class FocusSessionsController < ApplicationController
  before_action :require_login

  def main
    @focus_session = FocusSession.new
    @recent_focus_sessions = current_user.focus_sessions.order(created_at: :desc).limit(3)
    @activity_metrics = {
      focus_sessions: current_user.focus_sessions.count,
      activity_tracks: current_user.activity_tracks.count,
      average_energy: current_user.focus_sessions.average(:energy_level)&.round(1) || 0
    }
  end

  def create
    @focus_session = current_user.focus_sessions.new(focus_session_params)

    if @focus_session.save
      redirect_to main_topic_path(focus_session_id: @focus_session.id)
    else
      @recent_focus_sessions = current_user.focus_sessions.order(created_at: :desc).limit(3)
      @activity_metrics = {
        focus_sessions: current_user.focus_sessions.count,
        activity_tracks: current_user.activity_tracks.count,
        average_energy: current_user.focus_sessions.average(:energy_level)&.round(1) || 0
      }
      render :main
    end
  end

  private

  def focus_session_params
    params.require(:focus_session).permit(:subject, :topic, :energy_level)
  end
end
