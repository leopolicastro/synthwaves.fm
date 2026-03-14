require "rails_helper"

RSpec.describe Logo::Component, type: :component do
  include ViewComponent::TestHelpers

  def render_component(**options)
    render_inline(described_class.new(**options))
  end

  describe "text" do
    it "renders synthwaves.fm by default" do
      html = render_component
      expect(html.text).to include("synthwaves.fm")
    end

    it "hides text when text: false" do
      html = render_component(icon: true, text: false)
      expect(html.at_css(".font-display")).to be_nil
    end
  end

  describe "gradient classes" do
    it "applies the blue-to-pink gradient" do
      html = render_component
      text_span = html.at_css(".font-display")
      expect(text_span["class"]).to include("bg-gradient-to-r", "from-blue-400", "to-pink-500", "bg-clip-text", "text-transparent")
    end
  end

  describe "size variants" do
    it "renders sm size" do
      html = render_component(size: :sm)
      text_span = html.at_css(".font-display")
      expect(text_span["class"]).to include("text-sm")
    end

    it "renders md size" do
      html = render_component(size: :md)
      text_span = html.at_css(".font-display")
      expect(text_span["class"]).to include("text-lg")
    end

    it "renders lg size" do
      html = render_component(size: :lg)
      text_span = html.at_css(".font-display")
      expect(text_span["class"]).to include("text-5xl")
      expect(text_span["class"]).to include("font-bold")
    end

    it "defaults to md size" do
      html = render_component
      text_span = html.at_css(".font-display")
      expect(text_span["class"]).to include("text-lg")
    end
  end

  describe "icon" do
    it "does not render the icon by default" do
      html = render_component
      expect(html.css("img")).to be_empty
    end

    it "renders the sun icon when icon: true" do
      html = render_component(icon: true)
      img = html.at_css("img")
      expect(img).to be_present
      expect(img["alt"]).to eq("synthwaves.fm")
    end

    it "sizes the icon for sm" do
      html = render_component(size: :sm, icon: true)
      img = html.at_css("img")
      expect(img["class"]).to include("w-7", "h-7")
    end

    it "sizes the icon for md" do
      html = render_component(size: :md, icon: true)
      img = html.at_css("img")
      expect(img["class"]).to include("w-9", "h-9")
    end
  end
end
