class API::V1::PlayHistoriesController < API::V1::BaseController
  def index
    scope = current_user.play_histories.includes(track: [:artist, :album]).order(played_at: :desc)
    pagy, histories = pagy(:offset, scope, limit: per_page)

    render json: {
      play_histories: histories.map { |h| API::V1::PlayHistorySerializer.to_full(h) },
      pagination: pagination_meta(pagy)
    }
  end

  def create
    track = current_user.tracks.find(params[:track_id])
    history = current_user.play_histories.create!(track: track, played_at: Time.current)

    render json: API::V1::PlayHistorySerializer.to_full(history), status: :created
  rescue ActiveRecord::RecordNotFound
    render_error("Track not found", status: :not_found)
  end
end
