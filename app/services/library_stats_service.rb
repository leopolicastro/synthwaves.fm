class LibraryStatsService
  def self.call(user:)
    new(user: user).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    {
      track_count: track_count,
      album_count: album_count,
      artist_count: artist_count,
      total_duration: total_duration,
      total_file_size: total_file_size,
      avg_track_duration: avg_track_duration,
      top_genres: top_genres
    }
  end

  private

  def track_count
    @user.tracks.music.count
  end

  def album_count
    @user.albums.music.count
  end

  def artist_count
    @user.artists.music.count
  end

  def total_duration
    @user.tracks.music.sum(:duration).to_f
  end

  def total_file_size
    @user.tracks.music.sum(:file_size).to_i
  end

  def avg_track_duration
    @user.tracks.music.average(:duration).to_f
  end

  def top_genres(limit: 8)
    @user.tracks.music
      .joins(:album)
      .where("albums.genre IS NOT NULL AND albums.genre != ''")
      .group("albums.genre")
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(limit)
      .count
  end
end
