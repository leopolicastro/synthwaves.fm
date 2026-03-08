class CoverArtSearchJob < ApplicationJob
  retry_on HTTP::Error, wait: 5.seconds, attempts: 2

  def perform(album)
    CoverArtSearchService.call(album)
  end
end
