class AiDjService
  def self.call(user:)
    new(user: user).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    build_prompt
  end

  private

  def build_prompt
    parts = []
    parts << system_preamble
    parts << listening_context if top_artists.any?
    parts << library_context if available_artists.any?
    parts << request
    parts.join("\n\n")
  end

  def system_preamble
    <<~PROMPT.strip
      You are DJ Synth, a music-obsessed AI DJ for synthwaves.fm. You have a deep knowledge
      of music across all genres but especially love discovering connections between artists
      and unexpected recommendations. Your personality is enthusiastic but knowledgeable —
      think a late-night college radio DJ who genuinely loves every track they play.

      Format your response as a curated set list with commentary. For each recommendation:
      1. Name the artist and track/album
      2. Explain WHY you're recommending it based on the listener's taste
      3. Draw connections to artists they already love

      Use markdown formatting. Keep it conversational and fun.
    PROMPT
  end

  def listening_context
    sections = []

    if top_artists.any?
      artist_list = top_artists.map { |a| "#{a.name} (#{a.play_count} plays)" }.join(", ")
      sections << "**Top Artists:** #{artist_list}"
    end

    if top_tracks.any?
      track_list = top_tracks.map { |t| "#{t.artist_name} — #{t.title} (#{t.play_count} plays)" }.join(", ")
      sections << "**Top Tracks:** #{track_list}"
    end

    if top_genres.any?
      genre_list = top_genres.map { |g| "#{g.genre} (#{g.play_count} plays)" }.join(", ")
      sections << "**Top Genres:** #{genre_list}"
    end

    "Here's what this listener has been into:\n#{sections.join("\n")}"
  end

  def library_context
    artist_names = available_artists.map(&:name).join(", ")
    "**Available in their library:** #{artist_names}\n\nRecommend from their library when possible, but also suggest new artists they should check out."
  end

  def request
    "Based on this listener's taste, create a personalized set of 8-10 track recommendations. Mix familiar favorites from their library with new discoveries."
  end

  def top_artists
    @top_artists ||= @user.play_histories
      .joins(track: :artist)
      .select("artists.name, COUNT(*) AS play_count")
      .group("artists.name")
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(15)
  end

  def top_tracks
    @top_tracks ||= @user.play_histories
      .joins(track: :artist)
      .select("tracks.title, artists.name AS artist_name, COUNT(*) AS play_count")
      .group("tracks.title, artists.name")
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(10)
  end

  def top_genres
    @top_genres ||= @user.play_histories
      .joins(track: :album)
      .where("albums.genre IS NOT NULL AND albums.genre != ''")
      .select("albums.genre, COUNT(*) AS play_count")
      .group("albums.genre")
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(5)
  end

  def available_artists
    @available_artists ||= Artist.music
      .order(:name)
      .limit(50)
  end
end
