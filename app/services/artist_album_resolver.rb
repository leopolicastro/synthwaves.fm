class ArtistAlbumResolver
  def self.call(user:, artist_name:, album_title:, year: nil, genre: nil)
    artist = user.artists.find_or_create_by!(name: artist_name || "Unknown Artist")
    album = user.albums.find_or_create_by!(title: album_title || "Unknown Album", artist: artist) do |a|
      a.year = year
      a.genre = genre
    end
    [artist, album]
  end
end
