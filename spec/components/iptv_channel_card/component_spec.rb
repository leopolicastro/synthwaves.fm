require "rails_helper"

RSpec.describe IPTVChannelCard::Component, type: :component do
  include ViewComponent::TestHelpers

  let(:category) { create(:iptv_category, name: "News") }
  let(:channel) do
    create(:iptv_channel,
      name: "CNN International",
      stream_url: "https://stream.example.com/cnn.m3u8",
      logo_url: "https://example.com/cnn.png",
      country: "US",
      iptv_category: category)
  end

  def render_component(channel:)
    render_inline(described_class.new(channel: channel))
  end

  it "renders the channel name" do
    html = render_component(channel: channel)
    expect(html.text).to include("CNN International")
  end

  it "renders the stream URL as a data param" do
    html = render_component(channel: channel)
    button = html.at_css("button")
    expect(button["data-hls-player-url-param"]).to eq("https://stream.example.com/cnn.m3u8")
  end

  it "renders the channel logo" do
    html = render_component(channel: channel)
    img = html.at_css("img")
    expect(img["src"]).to eq("https://example.com/cnn.png")
  end

  it "renders the category name" do
    html = render_component(channel: channel)
    expect(html.text).to include("News")
  end

  it "renders the country" do
    html = render_component(channel: channel)
    expect(html.text).to include("US")
  end

  it "renders without a logo" do
    channel_no_logo = create(:iptv_channel, name: "No Logo", logo_url: nil)
    html = render_component(channel: channel_no_logo)
    expect(html.at_css("img")).to be_nil
    expect(html.at_css("svg")).to be_present
  end

  it "renders without a category" do
    channel_no_cat = create(:iptv_channel, name: "No Category", iptv_category: nil)
    html = render_component(channel: channel_no_cat)
    expect(html.text).to include("No Category")
  end

  it "links to the channel show page" do
    html = render_component(channel: channel)
    link = html.at_css("a")
    expect(link["href"]).to eq("/tv/channels/#{channel.id}")
  end
end
