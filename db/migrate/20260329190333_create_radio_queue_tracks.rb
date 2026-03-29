class CreateRadioQueueTracks < ActiveRecord::Migration[8.2]
  def change
    create_table :radio_queue_tracks do |t|
      t.references :radio_station, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true
      t.integer :position, null: false
      t.datetime :played_at

      t.timestamps
    end

    add_index :radio_queue_tracks, [:radio_station_id, :position], unique: true
    add_index :radio_queue_tracks, [:radio_station_id, :played_at]

    remove_reference :radio_stations, :queued_track, foreign_key: {to_table: :tracks}
  end
end
