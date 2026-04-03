module Subsonic
  class PlaylistSerializer
    def self.to_entry(playlist, owner:)
      {
        id: playlist.id.to_s,
        name: playlist.name,
        songCount: playlist.tracks.merge(Track.streamable).size,
        duration: playlist.tracks.merge(Track.streamable).sum(:duration).to_i,
        owner: owner,
        public: false
      }
    end
  end
end
