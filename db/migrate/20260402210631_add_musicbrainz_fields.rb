class AddMusicbrainzFields < ActiveRecord::Migration[8.2]
  def change
    add_column :tracks, :musicbrainz_recording_id, :string
    add_column :tracks, :musicbrainz_enrichment_status, :string
    add_column :tracks, :musicbrainz_enriched_at, :datetime

    add_index :tracks, :musicbrainz_recording_id
    add_index :tracks, :musicbrainz_enrichment_status

    add_column :albums, :musicbrainz_release_id, :string
    add_index :albums, :musicbrainz_release_id

    add_column :artists, :musicbrainz_artist_id, :string
    add_index :artists, :musicbrainz_artist_id
  end
end
