require "rails_helper"

RSpec.describe BottomTabBarComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:user) { create(:user) }

  def render_component(current_path: "/music")
    render_inline(described_class.new(current_path: current_path, user: user))
  end

  describe "tab rendering" do
    it "renders Library, Listen, Watch, and Search tabs" do
      html = render_component
      expect(html.at_css("a[href='/library']")).to be_present
      expect(html.at_css("a[href='/music']")).to be_present
      expect(html.at_css("a[href='/tv']")).to be_present
      expect(html.at_css("a[href='/search']")).to be_present
      expect(html.text).to include("Library", "Listen", "Watch", "Search")
    end
  end

  describe "active state" do
    it "highlights Listen tab on /music" do
      html = render_component(current_path: "/music")
      listen_link = html.at_css("a[href='/music']")
      expect(listen_link["class"]).to include("text-neon-cyan")
    end

    it "highlights Listen tab on /artists/1" do
      html = render_component(current_path: "/artists/1")
      listen_link = html.at_css("a[href='/music']")
      expect(listen_link["class"]).to include("text-neon-cyan")
    end

    it "highlights Listen tab on /albums/5" do
      html = render_component(current_path: "/albums/5")
      listen_link = html.at_css("a[href='/music']")
      expect(listen_link["class"]).to include("text-neon-cyan")
    end

    it "highlights Library tab on /library" do
      html = render_component(current_path: "/library")
      library_link = html.at_css("a[href='/library']")
      expect(library_link["class"]).to include("text-neon-cyan")
    end

    it "highlights Library tab on /playlists" do
      html = render_component(current_path: "/playlists")
      library_link = html.at_css("a[href='/library']")
      expect(library_link["class"]).to include("text-neon-cyan")
    end

    it "highlights Library tab on /favorites" do
      html = render_component(current_path: "/favorites")
      library_link = html.at_css("a[href='/library']")
      expect(library_link["class"]).to include("text-neon-cyan")
    end

    it "highlights Search tab on /search" do
      html = render_component(current_path: "/search")
      search_link = html.at_css("a[href='/search']")
      expect(search_link["class"]).to include("text-neon-cyan")
    end

    it "highlights Watch tab on /tv" do
      html = render_component(current_path: "/tv")
      watch_link = html.at_css("a[href='/tv']")
      expect(watch_link["class"]).to include("text-neon-cyan")
    end

    it "does not highlight any tab on unrelated paths" do
      html = render_component(current_path: "/profile")
      html.css("nav a").each do |link|
        expect(link["class"]).to include("text-white")
        expect(link["class"]).not_to include("text-neon-cyan")
      end
    end
  end

  describe "structure" do
    it "renders a nav element hidden on md+" do
      html = render_component
      nav = html.at_css("nav")
      expect(nav["class"]).to include("md:hidden")
      expect(nav["class"]).to include("fixed")
      expect(nav["class"]).to include("bottom-16")
    end
  end
end
