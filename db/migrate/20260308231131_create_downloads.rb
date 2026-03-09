class CreateDownloads < ActiveRecord::Migration[8.1]
  def change
    create_table :downloads do |t|
      t.references :user, null: false, foreign_key: true
      t.string :downloadable_type, null: false
      t.integer :downloadable_id
      t.string :status, default: "pending", null: false
      t.integer :total_tracks, default: 0
      t.integer :processed_tracks, default: 0
      t.string :error_message

      t.timestamps
    end

    add_index :downloads, [:user_id, :downloadable_type, :downloadable_id]
  end
end
