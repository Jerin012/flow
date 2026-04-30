class DashboardController < ApplicationController
  before_action :require_login

  def show
    @active_focus_session = current_user.focus_sessions.in_progress.order(updated_at: :desc).first
    @stats = {
      focus_sessions: current_user.focus_sessions.completed.count,
      active_notes: current_user.notes.active.count,
      tracked_minutes: current_user.activity_tracks.sum(:duration_minutes)
    }
    @recent_focus_sessions = current_user.focus_sessions.order(updated_at: :desc).limit(5)
    @recent_activity_tracks = current_user.activity_tracks.order(created_at: :desc).limit(12)
    @recent_notes = current_user.notes.active.includes(:focus_session).order(updated_at: :desc).limit(4)
  end
end
