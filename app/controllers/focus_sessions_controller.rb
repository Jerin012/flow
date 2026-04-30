class FocusSessionsController < ApplicationController
  before_action :require_login
  before_action :set_focus_session, only: %i[show activate sync_state reset_state]

  def main
    @focus_session = FocusSession.new
    @recent_focus_sessions = current_user.focus_sessions.order(created_at: :desc).limit(3)
    @activity_metrics = {
      focus_sessions: current_user.focus_sessions.count,
      activity_tracks: current_user.activity_tracks.count,
      average_energy: current_user.focus_sessions.average(:energy_level)&.round(1) || 0
    }
  end

  def new
    @focus_session = FocusSession.new
    @recent_focus_sessions = current_user.focus_sessions.order(created_at: :desc).limit(3)
    @activity_metrics = {
      focus_sessions: current_user.focus_sessions.completed.count,
      activity_tracks: current_user.activity_tracks.count,
      average_energy: current_user.focus_sessions.average(:energy_level)&.round(1) || 0
    }
    render :main
  end

  def create
    @focus_session = current_user.focus_sessions.new(focus_session_params)

    if @focus_session.save
      redirect_to activity_tracking_path(focus_session_id: @focus_session.id)
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

  def show
    redirect_to activity_tracking_path(focus_session_id: @focus_session.id)
  end

  def activate
    @focus_session.update!(timer_state_attributes(status: "active"))
    render json: { ok: true, timer: @focus_session.timer_resume_payload }
  end

  def sync_state
    @focus_session.update!(timer_state_attributes)
    render json: { ok: true, timer: @focus_session.timer_resume_payload }
  end

  def reset_state
    @focus_session.update!(
      status: "draft",
      started_at: nil,
      ended_at: nil,
      duration_minutes: nil,
      planned_duration_minutes: nil,
      elapsed_focus_ms: 0,
      elapsed_break_ms: 0,
      last_synced_at: nil,
      session_data: nil
    )

    render json: { ok: true }
  end

  private

  def set_focus_session
    @focus_session = current_user.focus_sessions.find(params[:id])
  end

  def focus_session_params
    params.require(:focus_session).permit(:subject, :topic, :energy_level)
  end

  def timer_state_attributes(status: nil)
    payload = params.fetch(:timer, {}).permit(
      :status,
      :started_at,
      :planned_duration_minutes,
      :elapsed_focus_ms,
      :elapsed_break_ms,
      :state
    )

    {
      status: status || payload[:status] || @focus_session.status || "draft",
      started_at: payload[:started_at].presence || @focus_session.started_at || Time.current,
      planned_duration_minutes: payload[:planned_duration_minutes].presence || @focus_session.planned_duration_minutes,
      elapsed_focus_ms: payload[:elapsed_focus_ms].presence || 0,
      elapsed_break_ms: payload[:elapsed_break_ms].presence || 0,
      last_synced_at: Time.current,
      session_data: payload[:state].presence || @focus_session.session_data
    }
  end
end
