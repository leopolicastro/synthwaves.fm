class YoutubeImportJob < ApplicationJob
  queue_as :imports

  def perform(url, category: "music", download: false, user_id: nil, playlist_id: nil, new_playlist_name: nil, artist_id: nil)
    user = User.find(user_id)
    artist = artist_id ? user.artists.find_by(id: artist_id) : nil
    album = YoutubePlaylistImportService.call(url, category: category, api_key: user.youtube_api_key, user: user, artist: artist)

    if download && album && user_id
      album.tracks.where.not(youtube_video_id: [nil, ""]).find_each do |track|
        next if track.audio_file.attached?

        video_url = "https://www.youtube.com/watch?v=#{track.youtube_video_id}"
        MediaDownloadJob.perform_later(track.id, video_url, user_id: user_id)
      end
    end

    add_tracks_to_playlist(album, user, playlist_id: playlist_id, new_playlist_name: new_playlist_name) if album
  end

  private

  def add_tracks_to_playlist(album, user, playlist_id:, new_playlist_name:)
    playlist = if new_playlist_name.present?
      user.playlists.create!(name: new_playlist_name)
    elsif playlist_id.present?
      user.playlists.find_by(id: playlist_id)
    end

    return unless playlist

    next_position = (playlist.playlist_tracks.maximum(:position) || 0) + 1

    album.tracks.order(:track_number).each do |track|
      unless playlist.playlist_tracks.exists?(track: track)
        playlist.playlist_tracks.create!(track: track, position: next_position)
        next_position += 1
      end
    end
  end
end
