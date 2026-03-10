class SmartPlaylistService
  DEFINITIONS = {
    most_played: {
      name: "Most Played",
      description: "Your all-time most listened tracks",
      icon: "fire",
      color: "neon-pink"
    },
    recently_added: {
      name: "Recently Added",
      description: "Tracks added in the last 30 days",
      icon: "sparkles",
      color: "neon-cyan"
    },
    unplayed: {
      name: "Unplayed",
      description: "Tracks you haven't listened to yet",
      icon: "question-mark",
      color: "neon-purple"
    },
    heavy_rotation: {
      name: "Heavy Rotation",
      description: "Frequently played in the last 2 weeks",
      icon: "refresh",
      color: "laser-green"
    },
    deep_cuts: {
      name: "Deep Cuts",
      description: "Tracks played only once or twice",
      icon: "eye",
      color: "amber-400"
    }
  }.freeze

  def self.call(user:, playlist_id:, limit: 50)
    new(user: user, playlist_id: playlist_id, limit: limit).call
  end

  def self.all_definitions
    DEFINITIONS
  end

  def initialize(user:, playlist_id:, limit:)
    @user = user
    @playlist_id = playlist_id.to_sym
    @limit = limit
  end

  def call
    return Track.none unless DEFINITIONS.key?(@playlist_id)

    send(@playlist_id)
  end

  private

  def most_played
    Track.music
      .joins(:play_histories)
      .where(play_histories: {user_id: @user.id})
      .group("tracks.id")
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(@limit)
  end

  def recently_added
    Track.music
      .where("tracks.created_at >= ?", 30.days.ago)
      .order(created_at: :desc)
      .limit(@limit)
  end

  def unplayed
    Track.music
      .left_joins(:play_histories)
      .where(play_histories: {id: nil})
      .or(
        Track.music
          .left_joins(:play_histories)
          .where.not(play_histories: {user_id: @user.id})
      )
      .distinct
      .order(created_at: :desc)
      .limit(@limit)
  end

  def heavy_rotation
    Track.music
      .joins(:play_histories)
      .where(play_histories: {user_id: @user.id, played_at: 2.weeks.ago..})
      .group("tracks.id")
      .having(Arel.sql("COUNT(*) >= 3"))
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(@limit)
  end

  def deep_cuts
    Track.music
      .joins(:play_histories)
      .where(play_histories: {user_id: @user.id})
      .group("tracks.id")
      .having(Arel.sql("COUNT(*) BETWEEN 1 AND 2"))
      .order(Arel.sql("MAX(play_histories.played_at) DESC"))
      .limit(@limit)
  end
end
