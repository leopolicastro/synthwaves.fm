require "rails_helper"

RSpec.describe TrackRowComponent, type: :component do
  include ViewComponent::TestHelpers
  include Rails.application.routes.url_helpers
  let(:artist) { create(:artist, name: "Test Artist") }
  let(:album) { create(:album, title: "Test Album", artist: artist) }
  let(:track) { create(:track, title: "Test Song", artist: artist, album: album, duration: 245, track_number: 3) }

  def render_component(**options, &block)
    render_inline(described_class.new(track: track, **options), &block)
  end

  describe "hover styling" do
    it "uses synthwave hover class" do
      html = render_component
      row = html.at_css("[data-controller]")
      classes = row["class"]
      expect(classes).to include("hover:bg-gray-700/50")
      expect(classes).not_to include("gray-750")
    end
  end

  describe "stimulus wiring" do
    it "sets data-controller on the outer div" do
      html = render_component
      row = html.at_css("[data-controller]")
      expect(row["data-controller"]).to include("song-row")
    end

    it "sets track data values" do
      html = render_component
      row = html.at_css("[data-controller]")
      expect(row["data-song-row-track-id-value"]).to eq(track.id.to_s)
      expect(row["data-song-row-title-value"]).to eq("Test Song")
      expect(row["data-song-row-artist-value"]).to eq("Test Artist")
      expect(row["data-song-row-stream-url-value"]).to eq("/tracks/#{track.id}/stream")
    end

    it "has a play button with the correct data-action" do
      expect(render_component.css("button[data-action='song-row#play']")).to be_present
    end

    it "sets cover URL attribute when album has a cover image" do
      album.cover_image.attach(
        io: StringIO.new("fake image data"),
        filename: "cover.jpg",
        content_type: "image/jpeg"
      )
      html = render_component
      row = html.at_css("[data-controller]")
      expect(row["data-song-row-cover-url-value"]).to be_present
    end

    it "sets podcast attribute when artist is a podcast" do
      artist.update!(category: "podcast")
      html = render_component
      row = html.at_css("[data-controller]")
      expect(row["data-song-row-is-podcast-value"]).to eq("true")
    end

    it "omits cover URL and podcast attributes by default" do
      html = render_component
      row = html.at_css("[data-controller]")
      expect(row["data-song-row-cover-url-value"]).to be_nil
      expect(row["data-song-row-is-podcast-value"]).to be_nil
    end
  end

  describe "now-playing wiring" do
    it "includes now-playing in data-controller" do
      html = render_component
      row = html.at_css("[data-controller]")
      expect(row["data-controller"]).to include("now-playing")
    end

    it "sets data-now-playing-track-id-value to the track id" do
      html = render_component
      row = html.at_css("[data-controller]")
      expect(row["data-now-playing-track-id-value"]).to eq(track.id.to_s)
    end
  end

  describe "play button" do
    it "shows a play icon by default" do
      expect(render_component.css("button svg")).to be_present
    end

    it "shows the number when number is provided" do
      html = render_component(number: 7)
      number_span = html.at_css("button span")
      expect(number_span.text.strip).to eq("7")
    end

    it "shows number by default and play icon on hover when number is provided" do
      html = render_component(number: 7)
      number_span = html.at_css("button span")
      play_svg = html.at_css("button svg")
      expect(number_span["class"]).to include("group-hover/play:hidden")
      expect(play_svg["class"]).to include("hidden")
      expect(play_svg["class"]).to include("group-hover/play:block")
    end
  end

  describe "title" do
    it "shows plain title by default" do
      html = render_component
      title_el = html.at_css(".font-medium")
      expect(title_el.text.strip).to eq("Test Song")
      expect(title_el.css("a")).to be_empty
    end

    it "links title when link_title is true" do
      html = render_component(link_title: true)
      link = html.at_css(".font-medium a")
      expect(link).to be_present
      expect(link.text.strip).to eq("Test Song")
      expect(link["href"]).to eq("/tracks/#{track.id}")
    end
  end

  describe "subtitle" do
    it "shows artist and album by default" do
      html = render_component
      subtitle = html.at_css(".text-sm.text-gray-400")
      expect(subtitle.text).to include("Test Artist")
      expect(subtitle.text).to include("Test Album")
    end

    it "links artist and album when link_subtitle is true" do
      html = render_component(link_subtitle: true)
      links = html.css(".text-sm.text-gray-400 a")
      expect(links.size).to eq(2)
      expect(links[0].text.strip).to eq("Test Artist")
      expect(links[1].text.strip).to eq("Test Album")
    end

    it "hides album when show_album is false" do
      html = render_component(show_album: false)
      subtitle = html.at_css(".text-sm.text-gray-400")
      expect(subtitle.text).to include("Test Artist")
      expect(subtitle.text).not_to include("Test Album")
    end

    it "hides artist when it matches hide_artist_if" do
      html = render_component(hide_artist_if: artist, show_album: false)
      subtitle = html.at_css(".font-medium").parent.css(".text-sm.text-gray-400")
      expect(subtitle).to be_empty
    end

    it "shows artist when it differs from hide_artist_if" do
      other_artist = create(:artist, name: "Other Artist")
      other_track = create(:track, title: "Other Song", artist: other_artist, album: album, duration: 100)
      html = render_inline(described_class.new(track: other_track, hide_artist_if: artist, show_album: false))
      subtitle = html.at_css(".text-sm.text-gray-400")
      expect(subtitle.text).to include("Other Artist")
    end
  end

  describe "duration" do
    it "shows formatted duration by default" do
      html = render_component
      expect(html.text).to include("4:05")
    end

    it "hides duration when show_duration is false" do
      html = render_component(show_duration: false)
      expect(html.text).not_to include("4:05")
    end
  end

  describe "trailing slot" do
    it "renders trailing content" do
      html = render_component { |c| c.with_trailing { "<span class='extra'>Edit</span>".html_safe } }
      expect(html.at_css(".extra").text).to eq("Edit")
    end
  end
end
