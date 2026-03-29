module API
  module Internal
    class RadioStationsController < BaseController
      def next_track
        station = RadioStation.find(params[:id])

        if station.stopped?
          head :service_unavailable
          return
        end

        unless has_listeners?(station)
          advance_track_virtually(station)
          head :no_content
          return
        end

        # When Liquidsoap requests the next track, the previously queued
        # track is now actually playing — promote it to current_track
        if station.queued_track_id && station.queued_track_id != station.current_track_id
          station.update!(current_track_id: station.queued_track_id, last_track_at: Time.current)
          station.broadcast_now_playing
        end

        result = NextTrackService.call(station)

        if result
          render json: {
            url: result.url,
            track_id: result.track.id,
            title: result.track.title,
            artist: result.track.artist.name,
            duration: result.track.duration
          }
        else
          head :no_content
        end
      end

      def notify
        station = RadioStation.find(params[:id])

        case params[:event]
        when "track_started"
          station.update!(
            current_track_id: params[:track_id],
            last_track_at: Time.current,
            status: "active"
          )
          station.broadcast_now_playing
        when "error"
          station.update!(status: "error", error_message: params[:message])
        when "idle"
          station.update!(status: "idle")
        end

        head :ok
      end

      def active
        stations = RadioStation.where.not(status: "stopped")
          .includes(:playlist, :current_track)

        render json: stations.map { |s|
          {
            id: s.id,
            mount_point: s.mount_point,
            bitrate: s.bitrate,
            crossfade: s.crossfade,
            crossfade_duration: s.crossfade_duration,
            status: s.status
          }
        }
      end

      private

      DEFAULT_TRACK_DURATION = 240

      def has_listeners?(station)
        IcecastStatsService.listener_count(station.mount_point) > 0
      end

      def advance_track_virtually(station)
        return unless station.current_track && station.last_track_at

        duration = station.current_track.duration || DEFAULT_TRACK_DURATION
        return unless Time.current - station.last_track_at >= duration

        result = NextTrackService.call(station)
        return unless result

        station.update!(
          current_track: result.track,
          queued_track: result.track,
          last_track_at: Time.current
        )
        station.broadcast_now_playing
      end
    end
  end
end
