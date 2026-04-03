module Subsonic
  class AlbumSerializer
    def self.to_entry(album)
      streamable = album.tracks.merge(Track.streamable)
      {
        id: album.id.to_s,
        name: album.title,
        artist: album.artist.name,
        artistId: album.artist_id.to_s,
        songCount: streamable.size,
        duration: streamable.sum(&:duration).to_i,
        year: album.year,
        genre: album.genre,
        coverArt: album.id.to_s
      }.compact
    end
  end
end
