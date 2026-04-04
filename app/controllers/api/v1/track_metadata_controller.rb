class API::V1::TrackMetadataController < API::V1::BaseController
  def show
    tracks = current_user.tracks.music

    render json: {
      genres: tracks.genre_names,
      languages: tracks.available_languages,
      decades: tracks.available_decades
    }
  end
end
