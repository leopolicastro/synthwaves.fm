class CreateAlbums < ActiveRecord::Migration[8.1]
  def change
    create_table :albums do |t|
      t.string :title, null: false
      t.references :artist, null: false, foreign_key: true
      t.integer :year
      t.string :genre

      t.timestamps
    end
    add_index :albums, [:artist_id, :title], unique: true
  end
end
