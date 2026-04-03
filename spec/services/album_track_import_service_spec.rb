require "rails_helper"

RSpec.describe AlbumTrackImportService do
  let(:user) { create(:user, youtube_api_key: "test_key") }
  let(:artist) { create(:artist, name: "Test Artist", user: user) }
  let(:album) { create(:album, artist: artist, user: user) }
  let(:service) { described_class.new(album: album, user: user) }

  let(:youtube_video) do
    {video_id: "abc123", title: "Test Artist - Test Song", duration: 240.0}
  end

  describe "#find_missing_tracks" do
    it "returns empty array when album has no musicbrainz_release_id" do
      expect(service.find_missing_tracks).to eq([])
    end

    it "returns missing entries from MusicBrainz" do
      album.update!(musicbrainz_release_id: "mb-release-123")
      create(:track, album: album, artist: artist, user: user, title: "Existing Song", track_number: 1)

      mb_tracks = [
        {position: 1, title: "Existing Song", duration_ms: 200_000},
        {position: 2, title: "Missing Song", duration_ms: 300_000}
      ]

      allow(MusicBrainzDiscographyService).to receive(:fetch_release_tracks)
        .with("mb-release-123")
        .and_return({title: "Test Album", year: 2020, tracks: mb_tracks})

      entries = service.find_missing_tracks

      expect(entries.length).to eq(1)
      expect(entries.first[:title]).to eq("Missing Song")
      expect(entries.first[:type]).to eq(:missing)
    end
  end

  describe "#import_track" do
    it "creates a track and enqueues download when YouTube returns results" do
      youtube_api = instance_double(YoutubeAPIService)
      allow(YoutubeAPIService).to receive(:new).with(api_key: "test_key").and_return(youtube_api)
      allow(youtube_api).to receive(:search_videos)
        .with("Test Artist My Song", max_results: 1)
        .and_return([youtube_video])

      expect {
        track = service.import_track("My Song")

        expect(track).to be_persisted
        expect(track.title).to eq("My Song")
        expect(track.artist).to eq(artist)
        expect(track.album).to eq(album)
        expect(track.youtube_video_id).to eq("abc123")
        expect(track.duration).to eq(240.0)
      }.to change(Track, :count).by(1)
        .and have_enqueued_job(MediaDownloadJob)
    end

    it "returns nil when no YouTube results found" do
      youtube_api = instance_double(YoutubeAPIService)
      allow(YoutubeAPIService).to receive(:new).with(api_key: "test_key").and_return(youtube_api)
      allow(youtube_api).to receive(:search_videos).and_return([])

      expect(service.import_track("Nonexistent Song")).to be_nil
      expect(Track.count).to eq(0)
    end
  end

  describe "#import_missing_tracks" do
    it "raises error when album has no musicbrainz_release_id" do
      expect { service.import_missing_tracks }
        .to raise_error(AlbumTrackImportService::Error, "No MusicBrainz data available for this album.")
    end

    it "returns 0 when no tracks are missing" do
      album.update!(musicbrainz_release_id: "mb-release-123")
      create(:track, album: album, artist: artist, user: user, title: "Only Song", track_number: 1)

      mb_tracks = [{position: 1, title: "Only Song", duration_ms: 200_000}]
      allow(MusicBrainzDiscographyService).to receive(:fetch_release_tracks)
        .and_return({title: "Test Album", year: 2020, tracks: mb_tracks})

      expect(service.import_missing_tracks).to eq(0)
    end

    it "imports missing tracks and returns count" do
      album.update!(musicbrainz_release_id: "mb-release-123")
      create(:track, album: album, artist: artist, user: user, title: "Track 1", track_number: 1)

      mb_tracks = [
        {position: 1, title: "Track 1", duration_ms: 200_000},
        {position: 2, title: "Track 2", duration_ms: 250_000},
        {position: 3, title: "Track 3", duration_ms: 300_000}
      ]
      allow(MusicBrainzDiscographyService).to receive(:fetch_release_tracks)
        .and_return({title: "Test Album", year: 2020, tracks: mb_tracks})

      youtube_api = instance_double(YoutubeAPIService)
      allow(YoutubeAPIService).to receive(:new).with(api_key: "test_key").and_return(youtube_api)
      allow(youtube_api).to receive(:search_videos)
        .with("Test Artist Track 2", max_results: 1)
        .and_return([{video_id: "vid2", title: "Track 2", duration: 250.0}])
      allow(youtube_api).to receive(:search_videos)
        .with("Test Artist Track 3", max_results: 1)
        .and_return([{video_id: "vid3", title: "Track 3", duration: 300.0}])

      expect {
        count = service.import_missing_tracks
        expect(count).to eq(2)
      }.to change(Track, :count).by(2)
        .and have_enqueued_job(MediaDownloadJob).exactly(2).times
    end

    it "skips tracks with no YouTube results and counts only successful imports" do
      album.update!(musicbrainz_release_id: "mb-release-123")

      mb_tracks = [
        {position: 1, title: "Found Song", duration_ms: 200_000},
        {position: 2, title: "Not Found Song", duration_ms: 300_000}
      ]
      allow(MusicBrainzDiscographyService).to receive(:fetch_release_tracks)
        .and_return({title: "Test Album", year: 2020, tracks: mb_tracks})

      youtube_api = instance_double(YoutubeAPIService)
      allow(YoutubeAPIService).to receive(:new).with(api_key: "test_key").and_return(youtube_api)
      allow(youtube_api).to receive(:search_videos)
        .with("Test Artist Found Song", max_results: 1)
        .and_return([{video_id: "vid1", title: "Found Song", duration: 200.0}])
      allow(youtube_api).to receive(:search_videos)
        .with("Test Artist Not Found Song", max_results: 1)
        .and_return([])

      expect(service.import_missing_tracks).to eq(1)
    end
  end
end
