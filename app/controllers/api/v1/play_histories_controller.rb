class API::V1::PlayHistoriesController < API::V1::BaseController
  def index
    scope = current_user.play_histories.includes(track: [:artist, :album]).order(played_at: :desc)
    pagy, histories = pagy(:offset, scope, limit: per_page)

    render json: {
      play_histories: histories.map { |h| history_json(h) },
      pagination: pagination_meta(pagy)
    }
  end

  def create
    track = current_user.tracks.find(params[:track_id])
    history = current_user.play_histories.create!(track: track, played_at: Time.current)

    render json: history_json(history), status: :created
  rescue ActiveRecord::RecordNotFound
    render_error("Track not found", status: :not_found)
  end

  private

  def history_json(history)
    {
      id: history.id,
      track: {
        id: history.track.id,
        title: history.track.title,
        artist: {id: history.track.artist_id, name: history.track.artist.name},
        album: {id: history.track.album_id, title: history.track.album.title}
      },
      played_at: history.played_at
    }
  end
end
