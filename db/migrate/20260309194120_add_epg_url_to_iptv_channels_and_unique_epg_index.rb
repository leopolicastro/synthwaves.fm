class AddEPGUrlToIPTVChannelsAndUniqueEPGIndex < ActiveRecord::Migration[8.1]
  def change
    add_column :iptv_channels, :epg_url, :string

    # Remove duplicate epg_programmes before adding unique index
    reversible do |dir|
      dir.up do
        execute <<~SQL
          DELETE FROM epg_programmes
          WHERE id NOT IN (
            SELECT MIN(id) FROM epg_programmes
            GROUP BY channel_id, starts_at
          )
        SQL
      end
    end

    # Replace non-unique index with unique index for upsert support
    remove_index :epg_programmes, [:channel_id, :starts_at]
    add_index :epg_programmes, [:channel_id, :starts_at], unique: true
  end
end
