module SearchIndexable
  extend ActiveSupport::Concern

  private

  def reindex_tracks_search
    tracks.reload.find_each do |track|
      track.send(:update_search_index)
    end
  end
end
