class CreateRadioStations < ActiveRecord::Migration[8.2]
  def change
    create_table :radio_stations do |t|
      t.references :playlist, null: false, foreign_key: true, index: {unique: true}
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "stopped"
      t.string :mount_point, null: false
      t.string :playback_mode, null: false, default: "shuffle"
      t.integer :bitrate, null: false, default: 192
      t.boolean :crossfade, null: false, default: true
      t.float :crossfade_duration, null: false, default: 3.0
      t.references :current_track, foreign_key: {to_table: :tracks}
      t.integer :listener_count, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :last_track_at
      t.timestamps
    end

    add_index :radio_stations, :mount_point, unique: true
    add_index :radio_stations, :status
  end
end
