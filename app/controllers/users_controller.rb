class UsersController < ApplicationController
  def new
    @user = User.new
  end

  # SIGNUP
  def create
    @user = User.new(user_params)

    if @user.save
      session[:user_id] = @user.id
      redirect_to dashboard_path, notice: "Signup successful!"
    else
      render :new
    end
  end


# SHOW LOGIN PAGE (GET /login)
def login
  # just render login page
end

# HANDLE LOGIN SUBMIT (POST /login)
  def create_session
  @user = User.find_by(email: params[:user][:email])

  if @user&.authenticate(params[:user][:password])
    session[:user_id] = @user.id
    redirect_to dashboard_path, notice: "Logged in successfully!"
  else
    flash.now[:alert] = "Invalid email or password"
    render :login, status: :unprocessable_entity
  end
end

  # LOGOUT
  def destroy
    session[:user_id] = nil
    redirect_to login_path, notice: "Logged out!"
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
