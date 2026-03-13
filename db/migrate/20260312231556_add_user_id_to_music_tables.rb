class AddUserIdToMusicTables < ActiveRecord::Migration[8.1]
  def up
    add_column :artists, :user_id, :integer
    add_column :albums, :user_id, :integer
    add_column :tracks, :user_id, :integer

    # Backfill existing records to the first user (admin)
    first_user_id = User.first&.id
    if first_user_id
      Artist.unscoped.update_all(user_id: first_user_id)
      Album.unscoped.update_all(user_id: first_user_id)
      Track.unscoped.update_all(user_id: first_user_id)
    end

    change_column_null :artists, :user_id, false
    change_column_null :albums, :user_id, false
    change_column_null :tracks, :user_id, false

    # Replace unique index on artists.name with [user_id, name]
    remove_index :artists, :name
    add_index :artists, [:user_id, :name], unique: true
    add_index :albums, :user_id
    add_index :tracks, :user_id
  end

  def down
    remove_index :artists, [:user_id, :name]
    add_index :artists, :name, unique: true
    remove_index :albums, :user_id
    remove_index :tracks, :user_id

    remove_column :artists, :user_id
    remove_column :albums, :user_id
    remove_column :tracks, :user_id
  end
end
