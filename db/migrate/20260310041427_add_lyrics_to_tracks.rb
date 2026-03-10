class AddLyricsToTracks < ActiveRecord::Migration[8.1]
  def change
    add_column :tracks, :lyrics, :text
  end
end
