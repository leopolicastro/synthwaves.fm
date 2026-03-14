module FolderCard
  class Component < ViewComponent::Base
    def initialize(folder:)
      @folder = folder
    end

    private

    attr_reader :folder

    def video_count
      folder.videos.size
    end

    def season_count
      folder.videos.where.not(season_number: nil).distinct.count(:season_number)
    end
  end
end
