class TrackSearchIndexService
  def self.add(track)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        "INSERT INTO tracks_search (track_title, artist_name, album_title, track_id) VALUES (?, ?, ?, ?)",
        track.title, track.artist.name, track.album.title, track.id
      ])
    )
  end

  def self.remove(track)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        "DELETE FROM tracks_search WHERE rowid IN (SELECT rowid FROM tracks_search WHERE track_id = ?)",
        track.id.to_s
      ])
    )
  end

  def self.update(track)
    remove(track)
    add(track)
  end
end
