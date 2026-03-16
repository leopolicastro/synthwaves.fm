class ProfilesController < ApplicationController
  def show
    @user = Current.user
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(user_params)
      respond_to do |format|
        format.html { redirect_to profile_path, notice: "Profile updated successfully." }
        format.json { render json: {status: "ok", theme: @user.theme} }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: {errors: @user.errors.full_messages}, status: :unprocessable_entity }
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email_address, :subsonic_password, :youtube_api_key, :theme)
  end
end
