class CoverArtSearchJob < ApplicationJob
  retry_on HTTP::Error, wait: 5.seconds, attempts: 2

  def perform(album)
    return if album.cover_image.attached?

    CoverArtSearchService.call(album)
  end
end
