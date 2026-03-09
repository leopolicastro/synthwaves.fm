class AddFolderFieldsToVideos < ActiveRecord::Migration[8.1]
  def change
    add_reference :videos, :folder, null: true, foreign_key: true
    add_column :videos, :season_number, :integer
    add_column :videos, :episode_number, :integer
    add_index :videos, [:folder_id, :season_number, :episode_number]
  end
end
