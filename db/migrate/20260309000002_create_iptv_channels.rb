class CreateIPTVChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :iptv_channels do |t|
      t.string :name, null: false
      t.string :tvg_id
      t.string :stream_url, null: false
      t.string :logo_url
      t.string :country
      t.string :language
      t.references :iptv_category, foreign_key: true
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :iptv_channels, :tvg_id, unique: true
    add_index :iptv_channels, :name
    add_index :iptv_channels, :country
    add_index :iptv_channels, :active
  end
end
