require "rails_helper"

RSpec.describe TvPlayer::Component, type: :component do
  include ViewComponent::TestHelpers

  def render_component
    render_inline(described_class.new)
  end

  it "renders a turbo-permanent container" do
    html = render_component
    container = html.at_css("#tv-player")
    expect(container).to be_present
    expect(container["data-turbo-permanent"]).not_to be_nil
  end

  it "has hls-player and retro-tv controllers" do
    html = render_component
    controllers = html.at_css("#tv-player")["data-controller"]
    expect(controllers).to include("hls-player")
    expect(controllers).to include("retro-tv")
  end

  it "initializes retro-tv channels as empty array" do
    html = render_component
    expect(html.at_css("#tv-player")["data-retro-tv-channels-value"]).to eq("[]")
  end

  it "renders a hidden container target" do
    html = render_component
    container = html.at_css("[data-hls-player-target='container']")
    expect(container).to be_present
    expect(container["class"]).to include("hidden")
  end

  it "renders a video element" do
    html = render_component
    video = html.at_css("[data-hls-player-target='video']")
    expect(video).to be_present
    expect(video.name).to eq("video")
  end

  it "renders a close button" do
    html = render_component
    close_btn = html.at_css("[data-action='hls-player#close']")
    expect(close_btn).to be_present
  end

  it "renders channel up/down buttons" do
    html = render_component
    expect(html.at_css("[data-action='click->retro-tv#channelUp']")).to be_present
    expect(html.at_css("[data-action='click->retro-tv#channelDown']")).to be_present
  end

  it "renders a video wrapper target" do
    html = render_component
    wrapper = html.at_css("[data-hls-player-target='videoWrapper']")
    expect(wrapper).to be_present
  end

  it "renders loading and error overlays" do
    html = render_component
    expect(html.at_css("[data-hls-player-target='loading']")).to be_present
    expect(html.at_css("[data-hls-player-target='error']")).to be_present
  end

  it "renders a CC toggle button" do
    html = render_component
    cc_btn = html.at_css("[data-hls-player-target='ccButton']")
    expect(cc_btn).to be_present
    expect(cc_btn["data-action"]).to include("hls-player#toggleCC")
  end
end
