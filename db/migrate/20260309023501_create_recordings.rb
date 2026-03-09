class CreateRecordings < ActiveRecord::Migration[8.1]
  def change
    create_table :recordings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :iptv_channel, null: false, foreign_key: true
      t.references :epg_programme, foreign_key: true
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, default: "scheduled", null: false
      t.string :error_message
      t.integer :file_size
      t.float :duration
      t.timestamps
    end

    add_index :recordings, [:user_id, :status]
    add_index :recordings, :starts_at
  end
end
