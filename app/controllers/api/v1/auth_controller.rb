class API::V1::AuthController < ActionController::API
  def create
    api_key = APIKey.find_by(client_id: params[:client_id])

    if api_key&.authenticate_secret_key(params[:secret_key])
      if api_key.expired?
        render json: {error: "API key has expired"}, status: :unauthorized
      else
        api_key.touch_last_used!(request.remote_ip)
        token = JWTService.encode({user_id: api_key.user_id, api_key_id: api_key.id})
        render json: {token: token, expires_in: 3600}
      end
    else
      render json: {error: "Invalid credentials"}, status: :unauthorized
    end
  end
end
