class AddFavoritesWeightToRadioStations < ActiveRecord::Migration[8.2]
  def change
    add_column :radio_stations, :favorites_weight, :float, null: false, default: 2.0
  end
end
