require "rails_helper"

RSpec.describe Player::Component, type: :component do
  include ViewComponent::TestHelpers

  context "when unauthenticated" do
    before do
      allow(vc_test_controller).to receive(:authenticated?).and_return(nil)
    end

    it "does not render" do
      result = render_inline(described_class.new)
      expect(result.to_html.strip).to be_empty
    end
  end

  context "when authenticated" do
    let(:user) { create(:user) }

    before do
      allow(vc_test_controller).to receive(:authenticated?).and_return(user)
    end

    def rendered
      render_inline(described_class.new)
    end

    it "renders #player-bar with data-turbo-permanent" do
      html = rendered
      player_bar = html.at_css("#player-bar")
      expect(player_bar).to be_present
      expect(player_bar["data-turbo-permanent"]).not_to be_nil
    end

    it "renders #queue-panel-container" do
      expect(rendered.at_css("#queue-panel-container")).to be_present
    end

    it "renders #visualizer-panel-container" do
      expect(rendered.at_css("#visualizer-panel-container")).to be_present
    end

    it "renders #fullscreen-now-playing" do
      expect(rendered.at_css("#fullscreen-now-playing")).to be_present
    end

    it "renders keyboard shortcuts modal" do
      expect(rendered.at_css("[data-keyboard-shortcuts-target='helpModal']")).to be_present
    end

    it "includes player and queue Stimulus controllers" do
      player_bar = rendered.at_css("#player-bar")
      expect(player_bar["data-controller"]).to include("player")
      expect(player_bar["data-controller"]).to include("queue")
    end

    it "includes play history URL data attribute" do
      player_bar = rendered.at_css("#player-bar")
      expect(player_bar["data-player-play-history-url-value"]).to eq("/play_histories")
    end
  end
end
