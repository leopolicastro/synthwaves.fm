module TrackRow
  class Component < ViewComponent::Base
    include TracksHelper

    renders_one :trailing

    def initialize(track:, number: nil, link_title: false, link_subtitle: false,
      show_album: true, hide_artist_if: nil, show_duration: true)
      @track = track
      @number = number
      @link_title = link_title
      @link_subtitle = link_subtitle
      @show_album = show_album
      @hide_artist_if = hide_artist_if
      @show_duration = show_duration
    end

    private

    attr_reader :track, :number, :show_album, :hide_artist_if

    def link_title? = @link_title
    def link_subtitle? = @link_subtitle
    def show_album? = @show_album
    def show_duration? = @show_duration

    def show_artist?
      return true if hide_artist_if.nil?
      track.artist != hide_artist_if
    end

    def show_subtitle?
      show_artist? || show_album?
    end

    def subtitle_parts
      parts = []
      if show_artist?
        parts << {text: track.artist.name, url: link_subtitle? ? helpers.artist_path(track.artist) : nil}
      end
      if show_album?
        parts << {text: track.album.title, url: link_subtitle? ? helpers.album_path(track.album) : nil}
      end
      parts
    end
  end
end
