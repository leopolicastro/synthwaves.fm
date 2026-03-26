class RenameRadioStationsToExternalStreams < ActiveRecord::Migration[8.2]
  def change
    rename_table :radio_stations, :external_streams
  end
end
