module Lyrics
  class Component < ViewComponent::Base
    # @param track_id [Integer, nil] Pin to a specific track (e.g. show page). Nil = follow now-playing.
    # @param max_height [String] Tailwind max-height class
    # @param show_header [Boolean] Show "Lyrics" heading
    def initialize(track_id: nil, max_height: "max-h-[60vh]", show_header: false)
      @track_id = track_id
      @max_height = max_height
      @show_header = show_header
    end
  end
end
