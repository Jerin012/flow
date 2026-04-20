class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  helper_method :current_user  # makes it accessible in controllers and views

  private

  def require_login
    unless current_user
      redirect_to login_path, alert: "You must be logged in to access this page"
    end
  end

  def current_user
    # Returns the logged-in user, if any
    @current_user ||= User.find_by(id: session[:user_id])
  end
end
