class CreateSongDownloads < ActiveRecord::Migration[8.1]
  def change
    create_table :song_downloads do |t|
      t.string :job_id, null: false
      t.string :status, null: false, default: "queued"
      t.string :url, null: false
      t.string :source_type, null: false
      t.integer :total_tracks
      t.integer :tracks_received, null: false, default: 0
      t.integer :tracks_failed, null: false, default: 0
      t.string :webhook_token, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :song_downloads, :job_id, unique: true
    add_index :song_downloads, :webhook_token, unique: true
  end
end
