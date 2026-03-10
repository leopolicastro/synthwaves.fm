class API::Subsonic::SearchController < API::Subsonic::BaseController
  def search3
    query = params[:query].to_s
    artist_count = (params[:artistCount] || 20).to_i
    album_count = (params[:albumCount] || 20).to_i
    song_count = (params[:songCount] || 20).to_i
    pattern = "%#{query}%"

    artists = Artist.where("name LIKE ?", pattern).limit(artist_count)
    albums = Album.with_streamable_tracks.includes(:artist, :tracks).where("albums.title LIKE ?", pattern).limit(album_count)
    tracks = Track.streamable.includes(:album, :artist).where("title LIKE ?", pattern).limit(song_count)

    render_subsonic(searchResult3: {
      artist: artists.map { |a| {id: a.id.to_s, name: a.name, albumCount: a.albums.size} },
      album: albums.map { |a| album_to_entry(a) },
      song: tracks.map { |t| track_to_child(t) }
    })
  end
end
