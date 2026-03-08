require "rails_helper"

RSpec.describe BulkPlaylistMenuComponent, type: :component do
  include ViewComponent::TestHelpers
  include Rails.application.routes.url_helpers

  let(:artist) { create(:artist) }
  let(:album) { create(:album, artist: artist) }
  let(:tracks) { create_list(:track, 3, artist: artist, album: album) }
  let(:user) { create(:user) }
  let(:playlists) { create_list(:playlist, 2, user: user) }

  def render_component(tracks: self.tracks, playlists: self.playlists, **options)
    render_inline(described_class.new(tracks: tracks, playlists: playlists, **options))
  end

  it "does not render when tracks is empty" do
    expect(render_component(tracks: []).to_html).to be_empty
  end

  it "renders the 'Add All to Playlist' toggle button" do
    html = render_component
    button = html.at_css("button[data-action='click->playlist-menu#toggle']")
    expect(button).to be_present
    expect(button.text).to include("Add All to Playlist")
  end

  it "uses playlist-menu Stimulus controller" do
    html = render_component
    container = html.at_css("[data-controller='playlist-menu']")
    expect(container).to be_present
    expect(container["data-action"]).to include("click@window->playlist-menu#close")
  end

  it "renders a 'New Playlist' form with correct hidden fields" do
    html = render_component(new_playlist_name: "My Mix")
    form = html.at_css("form[action='#{playlists_path}']")
    expect(form).to be_present
    expect(form.at_css("input[name='playlist[name]']")["value"]).to eq("My Mix")

    hidden_ids = form.css("input[name='track_ids[]']").map { |i| i["value"].to_i }
    expect(hidden_ids).to eq(tracks.map(&:id))

    submit = form.at_css("button[type='submit']")
    expect(submit.text.strip).to eq("New Playlist")
  end

  it "renders one form per existing playlist with track_ids hidden fields" do
    html = render_component
    playlists.each do |playlist|
      form = html.at_css("form[action='#{playlist_tracks_path(playlist)}']")
      expect(form).to be_present

      hidden_ids = form.css("input[name='track_ids[]']").map { |i| i["value"].to_i }
      expect(hidden_ids).to eq(tracks.map(&:id))

      expect(form.at_css("button[type='submit']").text.strip).to eq(playlist.name)
    end
  end

  it "renders without existing playlists" do
    html = render_component(playlists: [])
    expect(html.at_css("form[action='#{playlists_path}']")).to be_present
    expect(html.css("form").size).to eq(1)
  end

  it "renders search input when playlists exist" do
    html = render_component
    input = html.at_css("input[data-playlist-menu-target='input']")
    expect(input).to be_present
    expect(input["placeholder"]).to include("Search")
  end

  it "does not render search input when no playlists" do
    html = render_component(playlists: [])
    expect(html.at_css("input[data-playlist-menu-target='input']")).not_to be_present
  end

  it "renders data-playlist-name attribute on each item wrapper" do
    html = render_component
    items = html.css("[data-playlist-menu-target='item']")
    expect(items.size).to eq(playlists.size)
    playlists.each do |playlist|
      item = html.at_css("[data-playlist-name='#{playlist.name}']")
      expect(item).to be_present
    end
  end
end
