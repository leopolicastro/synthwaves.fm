class DropSongDownloads < ActiveRecord::Migration[8.1]
  def change
    drop_table :song_downloads do |t|
      t.string :url, null: false
      t.string :source_type, null: false
      t.string :status, default: "queued", null: false
      t.string :job_id, null: false
      t.string :webhook_token, null: false
      t.integer :total_tracks
      t.integer :tracks_received, default: 0, null: false
      t.integer :tracks_failed, default: 0, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
      t.index :job_id, unique: true
      t.index :webhook_token, unique: true
    end
  end
end
