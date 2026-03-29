module API
  module Internal
    class RadioStationsController < BaseController
      def next_track
        station = RadioStation.find(params[:id])

        if station.stopped?
          head :service_unavailable
          return
        end

        result = NextTrackService.call(station)

        if result
          # Promote: the previously queued track is now actually playing.
          # The new track is queued for Liquidsoap to play next.
          station.update!(
            current_track_id: station.queued_track_id,
            queued_track: result.track,
            last_track_at: Time.current
          )
          station.broadcast_now_playing if station.current_track_id

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
    end
  end
end
