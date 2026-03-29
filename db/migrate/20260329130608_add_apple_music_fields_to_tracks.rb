class AddAppleMusicFieldsToTracks < ActiveRecord::Migration[8.2]
  def change
    add_column :tracks, :apple_music_id, :string
    add_column :tracks, :isrc, :string
    add_column :tracks, :content_rating, :string
    add_column :tracks, :language, :string
    add_column :tracks, :release_year, :integer
    add_column :tracks, :enrichment_status, :string
    add_column :tracks, :enriched_at, :datetime

    add_index :tracks, :apple_music_id
    add_index :tracks, :isrc
    add_index :tracks, :language
    add_index :tracks, :release_year
    add_index :tracks, :enrichment_status
  end
end
