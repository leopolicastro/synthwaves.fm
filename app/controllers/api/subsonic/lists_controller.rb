class API::Subsonic::ListsController < API::Subsonic::BaseController
  def get_album_list2
    type = params[:type] || "alphabeticalByName"
    size = (params[:size] || 10).to_i.clamp(1, 500)
    offset = (params[:offset] || 0).to_i

    albums = case type
    when "newest"
      current_user.albums.includes(:artist, :tracks).order(created_at: :desc)
    when "random"
      current_user.albums.includes(:artist, :tracks).order("RANDOM()")
    when "alphabeticalByName"
      current_user.albums.includes(:artist, :tracks).order(:title)
    when "alphabeticalByArtist"
      current_user.albums.includes(:artist, :tracks).joins(:artist).order("artists.name")
    when "byYear"
      from_year = params[:fromYear].to_i
      to_year = params[:toYear].to_i
      current_user.albums.includes(:artist, :tracks).where(year: from_year..to_year).order(:year)
    when "byGenre"
      current_user.albums.includes(:artist, :tracks).where(genre: params[:genre])
    else
      current_user.albums.includes(:artist, :tracks).order(:title)
    end

    render_subsonic(albumList2: {
      album: albums.with_streamable_tracks.offset(offset).limit(size).map { |a| album_to_entry(a) }
    })
  end

  def get_random_songs
    size = (params[:size] || 10).to_i.clamp(1, 500)
    tracks = current_user.tracks.streamable.includes(:album, :artist).order("RANDOM()").limit(size)
    render_subsonic(randomSongs: {
      song: tracks.map { |t| track_to_child(t) }
    })
  end
end
