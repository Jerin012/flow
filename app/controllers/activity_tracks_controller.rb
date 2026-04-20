class ActivityTracksController < ApplicationController
  before_action :require_login

  def main_topic
    @focus_session = current_user.focus_sessions.find_by(id: params[:focus_session_id])
    @activity_track = ActivityTrack.new
    @recent_activity_tracks = current_user.activity_tracks.order(created_at: :desc).limit(3)
  end

  def create
    @activity_track = current_user.activity_tracks.new(activity_track_params)
    @focus_session = current_user.focus_sessions.find_by(id: params[:focus_session_id])
    @activity_track.title = @focus_session&.topic.presence || @activity_track.title || "Untitled activity"
    @activity_track.session_data = "{}" if @activity_track.session_data.blank?

    if @activity_track.save
      redirect_to activity_track_path(@activity_track)
    else
      @recent_activity_tracks = current_user.activity_tracks.order(created_at: :desc).limit(3)
      render :main_topic, status: :unprocessable_entity
    end
  end

  def show
    @activity_track = current_user.activity_tracks.find(params[:id])
    @session_data = @activity_track.parsed_session_data
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
end
