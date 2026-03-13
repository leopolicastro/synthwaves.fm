class CreateVideoPlaybackPositions < ActiveRecord::Migration[8.1]
  def change
    create_table :video_playback_positions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :video, null: false, foreign_key: true
      t.float :position, null: false, default: 0
      t.timestamps
    end

    add_index :video_playback_positions, [:user_id, :video_id], unique: true
  end
end
