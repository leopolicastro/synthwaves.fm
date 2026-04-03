module Maintenance
  class DeleteEmptyArtistsTask < MaintenanceTasks::Task
    def collection
      Artist.where.missing(:albums)
    end

    def count
      collection.count
    end

    def process(artist)
      artist.tracks.find_each do |track|
        track.update!(artist: track.album.artist)
      end
      artist.destroy!
    end
  end
end
