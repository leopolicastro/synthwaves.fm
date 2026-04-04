class API::V1::TagsController < API::V1::BaseController
  def index
    scope = Tag.all
    scope = scope.where(tag_type: params[:type]) if params[:type].present?
    scope = scope.where("name LIKE ?", "#{params[:q]}%") if params[:q].present?
    scope = scope.order(:name)

    render json: {
      tags: API::V1::TagSerializer.render_as_hash(scope)
    }
  end
end
