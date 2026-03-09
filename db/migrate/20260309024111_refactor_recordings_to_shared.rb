class RefactorRecordingsToShared < ActiveRecord::Migration[8.1]
  def change
    create_table :user_recordings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recording, null: false, foreign_key: true
      t.timestamps
    end

    add_index :user_recordings, [:user_id, :recording_id], unique: true

    # Migrate existing data: create user_recordings from recordings.user_id
    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO user_recordings (user_id, recording_id, created_at, updated_at)
          SELECT user_id, id, created_at, updated_at FROM recordings WHERE user_id IS NOT NULL
        SQL
      end
    end

    remove_index :recordings, [:user_id, :status]
    remove_reference :recordings, :user, foreign_key: true

    add_index :recordings, [:iptv_channel_id, :epg_programme_id], unique: true, where: "status NOT IN ('failed', 'cancelled')"
    add_index :recordings, :status
  end
end
