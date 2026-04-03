class AlbumTrackImportService
  class Error < StandardError; end

  def initialize(album:, user:)
    @album = album
    @user = user
  end

  def find_missing_tracks
    return [] unless @album.musicbrainz_release_id.present?

    mb_data = MusicBrainzDiscographyService.fetch_release_tracks(@album.musicbrainz_release_id)
    owned_tracks = @album.tracks.order(disc_number: :asc, track_number: :asc)
    AlbumTracksMergeService.call(owned_tracks, mb_data[:tracks])
  end

  def import_track(title)
    video = search_youtube(title)
    return nil unless video

    create_track_from_video(title: title, video: video)
  end

  def import_missing_tracks
    raise Error, "No MusicBrainz data available for this album." unless @album.musicbrainz_release_id.present?

    missing = find_missing_tracks.select { |e| e[:type] == :missing }
    return 0 if missing.empty?

    imported = 0
    missing.each do |entry|
      video = search_youtube(entry[:title])
      next unless video

      create_track_from_video(
        title: entry[:title],
        video: video,
        track_number: entry[:position]
      )
      imported += 1
    end
    imported
  end

  private

  def search_youtube(title)
    query = "#{@album.artist.name} #{title}"
    api = YoutubeAPIService.new(api_key: @user.youtube_api_key)
    results = api.search_videos(query, max_results: 1)
    results.first
  end

  def create_track_from_video(title:, video:, track_number: nil)
    track = @user.tracks.create!(
      title: title,
      artist: @album.artist,
      album: @album,
      youtube_video_id: video[:video_id],
      duration: video[:duration],
      track_number: track_number
    )

    video_url = "https://www.youtube.com/watch?v=#{video[:video_id]}"
    MediaDownloadJob.perform_later(track.id, video_url, user_id: @user.id)

    track
  end
end
