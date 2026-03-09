class CreateInternetRadioStations < ActiveRecord::Migration[8.1]
  def change
    create_table :internet_radio_stations do |t|
      t.string :uuid
      t.string :name, null: false
      t.string :stream_url, null: false
      t.string :homepage_url
      t.string :favicon_url
      t.string :country
      t.string :country_code
      t.string :language
      t.string :tags
      t.string :codec
      t.integer :bitrate
      t.integer :votes, default: 0
      t.references :internet_radio_category, null: true, foreign_key: true
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :internet_radio_stations, :uuid, unique: true
    add_index :internet_radio_stations, :country_code
    add_index :internet_radio_stations, :active
  end
end
