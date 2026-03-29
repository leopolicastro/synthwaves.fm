class AddAppleMusicStorefrontToArtists < ActiveRecord::Migration[8.2]
  def change
    add_column :artists, :apple_music_storefront, :string
  end
end
