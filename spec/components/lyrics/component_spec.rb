require "rails_helper"

RSpec.describe Lyrics::Component, type: :component do
  include ViewComponent::TestHelpers

  it "renders the lyrics controller container" do
    html = render_inline(described_class.new)
    expect(html.at_css("[data-controller='lyrics']")).to be_present
    expect(html.at_css("[data-lyrics-target='content']")).to be_present
  end

  it "does not render header by default" do
    html = render_inline(described_class.new)
    expect(html.at_css("h3")).to be_nil
  end

  it "renders with a specific track ID" do
    html = render_inline(described_class.new(track_id: 42))
    expect(html.at_css("[data-lyrics-track-id-value='42']")).to be_present
  end

  it "renders header when show_header is true" do
    html = render_inline(described_class.new(show_header: true))
    expect(html.at_css("h3").text).to include("Lyrics")
  end

  it "applies custom max_height class" do
    html = render_inline(described_class.new(max_height: "max-h-96"))
    content = html.at_css("[data-lyrics-target='content']")
    expect(content["class"]).to include("max-h-96")
  end

  it "does not include track ID data attribute when no track_id" do
    html = render_inline(described_class.new)
    expect(html.at_css("[data-lyrics-track-id-value]")).to be_nil
  end
end
