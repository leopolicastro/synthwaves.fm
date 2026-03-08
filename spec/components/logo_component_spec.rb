require "rails_helper"

RSpec.describe LogoComponent, type: :component do
  include ViewComponent::TestHelpers

  def render_component(**options)
    render_inline(described_class.new(**options))
  end

  describe "text" do
    it "renders Synthwaves.fm" do
      html = render_component
      expect(html.text).to include("Synthwaves.fm")
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
      expect(html.css("svg")).to be_empty
    end

    it "renders the music note icon when icon: true" do
      html = render_component(icon: true)
      expect(html.at_css("svg")).to be_present
    end

    it "sizes the icon wrapper for sm" do
      html = render_component(size: :sm, icon: true)
      wrapper = html.at_css("svg").parent
      expect(wrapper["class"]).to include("w-7", "h-7")
    end

    it "sizes the icon wrapper for md" do
      html = render_component(size: :md, icon: true)
      wrapper = html.at_css("svg").parent
      expect(wrapper["class"]).to include("w-9", "h-9")
    end
  end
end
