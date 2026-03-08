class AddPlaylistTracksCountToPlaylists < ActiveRecord::Migration[8.1]
  def change
    add_column :playlists, :playlist_tracks_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE playlists SET playlist_tracks_count = (
            SELECT COUNT(*) FROM playlist_tracks WHERE playlist_tracks.playlist_id = playlists.id
          )
        SQL
      end
    end
  end
end
