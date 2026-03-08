class CreateArtists < ActiveRecord::Migration[8.1]
  def change
    create_table :artists do |t|
      t.string :name, null: false
      t.string :image_url

      t.timestamps
    end
    add_index :artists, :name, unique: true
  end
end
