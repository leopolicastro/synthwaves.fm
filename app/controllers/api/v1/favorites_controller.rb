class API::V1::FavoritesController < API::V1::BaseController
  ALLOWED_TYPES = %w[Track Album Artist].freeze

  def index
    scope = current_user.favorites.includes(:favorable).order(created_at: :desc)
    scope = scope.where(favorable_type: params[:type]) if params[:type].present? && ALLOWED_TYPES.include?(params[:type])

    pagy, favorites = pagy(:offset, scope, limit: per_page)

    render json: {
      favorites: favorites.map { |f| favorite_json(f) },
      pagination: pagination_meta(pagy)
    }
  end

  def create
    unless ALLOWED_TYPES.include?(params[:favorable_type])
      return render_error("favorable_type must be one of: #{ALLOWED_TYPES.join(", ")}")
    end

    favorable = find_favorable
    favorite = current_user.favorites.find_or_initialize_by(favorable: favorable)

    if favorite.new_record?
      favorite.save!
      render json: favorite_json(favorite), status: :created
    else
      render json: favorite_json(favorite), status: :ok
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def destroy
    favorite = if params[:id] != "0" && params[:id].present? && params[:favorable_type].blank?
      current_user.favorites.find(params[:id])
    else
      current_user.favorites.find_by!(favorable_type: params[:favorable_type], favorable_id: params[:favorable_id])
    end

    favorite.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  private

  def find_favorable
    case params[:favorable_type]
    when "Track" then current_user.tracks.find(params[:favorable_id])
    when "Album" then current_user.albums.find(params[:favorable_id])
    when "Artist" then current_user.artists.find(params[:favorable_id])
    end
  end

  def favorite_json(favorite)
    {
      id: favorite.id,
      favorable_type: favorite.favorable_type,
      favorable_id: favorite.favorable_id,
      favorable: favorable_summary(favorite.favorable),
      created_at: favorite.created_at
    }
  end

  def favorable_summary(favorable)
    case favorable
    when Track
      {id: favorable.id, title: favorable.title, artist: {name: favorable.artist.name}}
    when Album
      {id: favorable.id, title: favorable.title, artist: {name: favorable.artist.name}}
    when Artist
      {id: favorable.id, name: favorable.name}
    end
  end
end
