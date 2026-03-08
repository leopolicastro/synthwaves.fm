module PlaylistsHelper
  def playlist_tracks_as_text(playlist_tracks)
    playlist_tracks.map { |pt| format_track_line(pt.track) }.join("\n")
  end

  private

  def format_track_line(track)
    line = "#{track.artist.name} - #{track.title}"
    line += " | https://youtube.com/watch?v=#{track.youtube_video_id}" if track.youtube?
    line
  end
end
