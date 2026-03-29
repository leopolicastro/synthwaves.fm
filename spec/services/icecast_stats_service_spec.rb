require "rails_helper"

RSpec.describe IcecastStatsService do
  describe ".listener_count" do
    it "returns the listener count for a given mount point" do
      stub_icecast_stats("source" => {
        "listenurl" => "http://localhost:8000/chill.mp3",
        "listeners" => 5
      })

      expect(IcecastStatsService.listener_count("/chill.mp3")).to eq(5)
    end

    it "returns 0 for an unknown mount point" do
      stub_icecast_stats("source" => {
        "listenurl" => "http://localhost:8000/other.mp3",
        "listeners" => 3
      })

      expect(IcecastStatsService.listener_count("/unknown.mp3")).to eq(0)
    end

    it "returns 0 when Icecast is unreachable" do
      stub_request(:get, %r{status-json\.xsl}).to_raise(Errno::ECONNREFUSED)

      expect(IcecastStatsService.listener_count("/chill.mp3")).to eq(0)
    end

    it "returns 0 when Icecast returns an error" do
      stub_request(:get, %r{status-json\.xsl}).to_return(status: 500)

      expect(IcecastStatsService.listener_count("/chill.mp3")).to eq(0)
    end
  end

  describe ".all_mount_listeners" do
    it "returns a hash of mount points to listener counts" do
      stub_icecast_stats("source" => [
        {"listenurl" => "http://localhost:8000/a.mp3", "listeners" => 2},
        {"listenurl" => "http://localhost:8000/b.mp3", "listeners" => 0}
      ])

      result = IcecastStatsService.all_mount_listeners
      expect(result).to eq("/a.mp3" => 2, "/b.mp3" => 0)
    end

    it "handles a single source (hash instead of array)" do
      stub_icecast_stats("source" => {
        "listenurl" => "http://localhost:8000/solo.mp3",
        "listeners" => 1
      })

      result = IcecastStatsService.all_mount_listeners
      expect(result).to eq("/solo.mp3" => 1)
    end

    it "returns empty hash when no sources exist" do
      stub_icecast_stats({})

      expect(IcecastStatsService.all_mount_listeners).to eq({})
    end
  end

  def stub_icecast_stats(icestats_content)
    stub_request(:get, %r{status-json\.xsl})
      .to_return(
        status: 200,
        body: {"icestats" => icestats_content}.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end
end
