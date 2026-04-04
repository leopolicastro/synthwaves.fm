class API::V1::ProfileController < API::V1::BaseController
  def show
    render json: API::V1::ProfileSerializer.to_full(current_user)
  end

  def update
    if current_user.update(profile_params)
      render json: API::V1::ProfileSerializer.to_full(current_user)
    else
      render_validation_errors(current_user)
    end
  end

  private

  def profile_params
    params.permit(:name, :theme)
  end
end
