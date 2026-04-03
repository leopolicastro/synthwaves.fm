class Playlist < ApplicationRecord
  belongs_to :user
  has_many :playlist_tracks, -> { order(:position) }, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  has_one :radio_station, dependent: :destroy

  validates :name, presence: true

  def add_track(track)
    return nil if playlist_tracks.exists?(track: track)

    next_position = (playlist_tracks.maximum(:position) || 0) + 1
    playlist_tracks.create!(track: track, position: next_position)
  end

  def add_tracks(tracks)
    next_position = (playlist_tracks.maximum(:position) || 0) + 1
    added = 0

    tracks.each do |track|
      next if playlist_tracks.exists?(track: track)
      playlist_tracks.create!(track: track, position: next_position)
      next_position += 1
      added += 1
    end
    added
  end

  def random_cover_track
    tracks.joins(album: :cover_image_attachment).order("RANDOM()").first
  end

  def cover_albums(limit = 4)
    Album.where(id:
      playlist_tracks
        .joins(track: {album: :cover_image_attachment})
        .order(:position)
        .select("DISTINCT albums.id")
        .limit(limit)).includes(cover_image_attachment: :blob)
  end

  def self.preload_cover_albums(playlists, limit: 4)
    playlist_ids = playlists.map(&:id)
    return {} if playlist_ids.empty?

    # Load playlist_tracks with album ids, ordered by position
    rows = PlaylistTrack
      .where(playlist_id: playlist_ids)
      .joins(track: {album: :cover_image_attachment})
      .order(:playlist_id, :position)
      .pluck(:playlist_id, "albums.id")

    # Group by playlist, deduplicate albums, take first `limit` per playlist
    album_ids_by_playlist = {}
    rows.each do |playlist_id, album_id|
      ids = (album_ids_by_playlist[playlist_id] ||= [])
      ids << album_id unless ids.include?(album_id) || ids.size >= limit
    end

    # Bulk-load albums
    all_album_ids = album_ids_by_playlist.values.flatten.uniq
    albums_by_id = Album.where(id: all_album_ids)
      .includes(cover_image_attachment: :blob)
      .index_by(&:id)

    # Build result hash preserving order
    result = {}
    playlist_ids.each do |pid|
      ordered_ids = album_ids_by_playlist[pid] || []
      result[pid] = ordered_ids.filter_map { |aid| albums_by_id[aid] }
    end
    result
  end

  SORT_OPTIONS = {
    "name" => "Name",
    "playlist_tracks_count" => "Track Count",
    "updated_at" => "Recently Updated",
    "created_at" => "Recently Created"
  }.freeze

  scope :search, ->(query) {
    where("playlists.name LIKE :q", q: "%#{query}%") if query.present?
  }
end
