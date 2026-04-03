module Subsonic
  class TrackSerializer
    CONTENT_TYPES = {
      "mp3" => "audio/mpeg",
      "flac" => "audio/flac",
      "ogg" => "audio/ogg",
      "m4a" => "audio/mp4",
      "aac" => "audio/mp4",
      "opus" => "audio/opus"
    }.freeze

    def self.to_child(track)
      {
        id: track.id.to_s,
        parent: track.album_id.to_s,
        isDir: false,
        title: track.title,
        album: track.album.title,
        artist: track.artist.name,
        track: track.track_number,
        year: track.album.year,
        genre: track.album.genre,
        size: track.file_size,
        contentType: CONTENT_TYPES[track.file_format.to_s.downcase] || "audio/mpeg",
        suffix: track.file_format,
        duration: track.duration&.to_i,
        bitRate: track.bitrate,
        albumId: track.album_id.to_s,
        artistId: track.artist_id.to_s,
        type: "music"
      }.compact
    end
  end
end
