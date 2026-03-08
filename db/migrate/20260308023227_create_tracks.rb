class CreateTracks < ActiveRecord::Migration[8.1]
  def change
    create_table :tracks do |t|
      t.string :title, null: false
      t.references :album, null: false, foreign_key: true
      t.references :artist, null: false, foreign_key: true
      t.integer :track_number
      t.integer :disc_number, default: 1
      t.float :duration
      t.string :file_format
      t.integer :file_size
      t.integer :bitrate

      t.timestamps
    end
    add_index :tracks, [:album_id, :disc_number, :track_number]
  end
end
