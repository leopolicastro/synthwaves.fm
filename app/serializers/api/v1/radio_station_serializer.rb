module API
  module V1
    class RadioStationSerializer
      def self.to_full(station)
        {
          id: station.id,
          name: station.playlist.name,
          status: station.status,
          mount_point: station.mount_point,
          listen_url: station.listen_url,
          playback_mode: station.playback_mode,
          bitrate: station.bitrate,
          crossfade_duration: station.crossfade_duration,
          playlist: PlaylistSerializer.to_ref(station.playlist),
          current_track: station.current_track ? TrackSerializer.to_minimal(station.current_track) : nil,
          created_at: station.created_at
        }
      end
    end
  end
end
