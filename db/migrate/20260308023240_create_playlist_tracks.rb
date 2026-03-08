class CreatePlaylistTracks < ActiveRecord::Migration[8.1]
  def change
    create_table :playlist_tracks do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end
    add_index :playlist_tracks, [:playlist_id, :position], unique: true
  end
end
