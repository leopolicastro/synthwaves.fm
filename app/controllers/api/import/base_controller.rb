class API::Import::BaseController < ActionController::API
  include SubsonicAuthentication

  private

  def render_subsonic_error(code, message)
    render json: { error: message, code: code }, status: :unauthorized
  end
end
