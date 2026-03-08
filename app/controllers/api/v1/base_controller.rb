class API::V1::BaseController < ActionController::API
  before_action :authenticate_with_jwt!

  private

  def authenticate_with_jwt!
    token = request.headers["Authorization"]&.remove("Bearer ")
    return render_unauthorized unless token

    payload = JWTService.decode(token)
    return render_unauthorized unless payload

    @current_user = User.find_by(id: payload["user_id"])
    @current_api_key = APIKey.find_by(id: payload["api_key_id"])

    render_unauthorized unless @current_user
  end

  attr_reader :current_user

  attr_reader :current_api_key

  def render_unauthorized
    render json: {error: "Unauthorized"}, status: :unauthorized
  end

  def render_error(message, status: :unprocessable_content)
    render json: {error: message}, status: status
  end
end
