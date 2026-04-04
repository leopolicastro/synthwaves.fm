class API::V1::BaseController < ActionController::API
  include Pagy::Method
  include Orderable

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

  def render_not_found
    render json: {error: "Not found"}, status: :not_found
  end

  def render_validation_errors(record)
    render json: {errors: record.errors.full_messages}, status: :unprocessable_content
  end

  def pagination_meta(pagy)
    {page: pagy.page, per_page: pagy.limit, total_pages: pagy.pages, total_count: pagy.count}
  end

  def per_page
    [(params[:per_page] || 24).to_i, 100].min
  end
end
