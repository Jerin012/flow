class ActivityTracksController < ApplicationController
  before_action :require_login

  def main_topic
    @focus_session = current_user.focus_sessions.find_by(id: params[:focus_session_id]) ||
      current_user.focus_sessions.in_progress.order(updated_at: :desc).first
    return redirect_to(dashboard_path, alert: "Create a focus session first.") unless @focus_session

    @activity_track = ActivityTrack.new
    @recent_activity_tracks = current_user.activity_tracks.order(created_at: :desc).limit(12)
    @timer_resume_payload = @focus_session&.timer_resume_payload || {}
  end

  def create
    @activity_track = current_user.activity_tracks.new(activity_track_params)
    @focus_session = current_user.focus_sessions.find_by(id: params[:focus_session_id])
    @activity_track.title = @focus_session&.topic.presence || @activity_track.title || "Untitled activity"
    @activity_track.session_data = "{}" if @activity_track.session_data.blank?

    if @activity_track.save
      complete_focus_session! if @focus_session.present?
      redirect_to activity_track_path(@activity_track)
    else
      @recent_activity_tracks = current_user.activity_tracks.order(created_at: :desc).limit(12)
      @timer_resume_payload = @focus_session&.timer_resume_payload || {}
      render :main_topic, status: :unprocessable_entity
    end
  end

  def show
    @activity_track = current_user.activity_tracks.find(params[:id])
    @session_data = @activity_track.parsed_session_data
    @recent_activity_tracks = current_user.activity_tracks
      .where.not(id: @activity_track.id)
      .order(created_at: :desc)
      .limit(12)
  end

  private

  def activity_track_params
    params.require(:activity_track).permit(
      :title,
      :duration_minutes,
      :start_time,
      :end_time,
      :total_focus_ms,
      :session_data
    )
  end

  def complete_focus_session!
    duration_minutes = @activity_track.duration_minutes.to_i
    focus_ratio = if duration_minutes.positive?
      ((@activity_track.total_focus_minutes / duration_minutes) * 10).clamp(0, 10)
    else
      0
    end

    @focus_session.update!(
      status: "completed",
      started_at: @activity_track.start_time,
      ended_at: @activity_track.end_time,
      duration_minutes: duration_minutes,
      planned_duration_minutes: @focus_session.planned_duration_minutes || duration_minutes,
      elapsed_focus_ms: @activity_track.total_focus_ms,
      elapsed_break_ms: break_duration_ms_from(@activity_track.parsed_session_data),
      deep_work_score: focus_ratio.round(1),
      last_synced_at: Time.current,
      session_data: @activity_track.session_data
    )
  end

  def break_duration_ms_from(session_data)
    Array(session_data[:absenceLog]).sum do |entry|
      type = entry[:type] || entry["type"]
      next 0 unless type == "break"

      (entry[:durationMs] || entry["durationMs"]).to_i
    end
  end
end
