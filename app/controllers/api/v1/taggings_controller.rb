class API::V1::TaggingsController < API::V1::BaseController
  ALLOWED_TAGGABLE_TYPES = %w[Track Album Artist].freeze

  def create
    unless ALLOWED_TAGGABLE_TYPES.include?(params[:taggable_type])
      return render_error("taggable_type must be one of: #{ALLOWED_TAGGABLE_TYPES.join(", ")}")
    end

    tag = Tag.find_or_create_by!(
      name: params[:name].to_s.strip.downcase,
      tag_type: params[:tag_type]
    )

    tagging = current_user.taggings.find_or_create_by!(
      tag: tag,
      taggable_type: params[:taggable_type],
      taggable_id: params[:taggable_id]
    )

    render json: {
      id: tagging.id,
      tag: API::V1::TagSerializer.to_full(tag),
      taggable_type: tagging.taggable_type,
      taggable_id: tagging.taggable_id
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.message)
  end

  def destroy
    tagging = current_user.taggings.find(params[:id])
    tagging.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end
end
