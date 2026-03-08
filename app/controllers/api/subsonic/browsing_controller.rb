class API::Subsonic::BrowsingController < API::Subsonic::BaseController
  def get_music_folders
    render_subsonic(musicFolders: {musicFolder: [{id: 1, name: "Music"}]})
  end

  def get_indexes
    artists = Artist.order(:name)
    indexes = artists.group_by { |a| a.name[0]&.upcase || "#" }.map do |letter, group|
      {name: letter, artist: group.map { |a| {id: a.id.to_s, name: a.name} }}
    end
    render_subsonic(indexes: {index: indexes})
  end

  def get_artists
    artists = Artist.order(:name)
    indexes = artists.group_by { |a| a.name[0]&.upcase || "#" }.map do |letter, group|
      {name: letter, artist: group.map { |a| {id: a.id.to_s, name: a.name, albumCount: a.albums.size} }}
    end
    render_subsonic(artists: {index: indexes})
  end

  def get_artist
    artist = Artist.find(params[:id])
    albums = artist.albums.includes(:tracks)
    render_subsonic(artist: {
      id: artist.id.to_s,
      name: artist.name,
      albumCount: albums.size,
      album: albums.map { |a| album_to_entry(a) }
    })
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Artist not found")
  end

  def get_album
    album = Album.includes(:artist, tracks: :artist).find(params[:id])
    render_subsonic(album: album_to_entry(album).merge(
      song: album.tracks.order(:disc_number, :track_number).map { |t| track_to_child(t) }
    ))
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Album not found")
  end

  def get_song
    track = Track.includes(:album, :artist).find(params[:id])
    render_subsonic(song: track_to_child(track))
  rescue ActiveRecord::RecordNotFound
    render_subsonic_error(70, "Song not found")
  end
end
