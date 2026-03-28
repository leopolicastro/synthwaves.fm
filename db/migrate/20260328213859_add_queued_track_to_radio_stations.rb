class AddQueuedTrackToRadioStations < ActiveRecord::Migration[8.2]
  def change
    add_reference :radio_stations, :queued_track, foreign_key: {to_table: :tracks}
  end
end
