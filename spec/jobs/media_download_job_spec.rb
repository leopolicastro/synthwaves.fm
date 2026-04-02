require "rails_helper"

RSpec.describe MediaDownloadJob, type: :job do
  let(:user) { create(:user) }
  let(:track) { create(:track, :youtube) }
  let(:url) { "https://youtube.com/watch?v=#{track.youtube_video_id}" }
  let(:temp_mp3) { Tempfile.new(["test", ".mp3"]) }

  before do
    File.write(temp_mp3.path, "fake mp3 data")
  end

  after { temp_mp3.close! }

  describe "#perform" do
    it "downloads audio and attaches it to the track" do
      allow(MediaDownloadService).to receive(:download_audio).and_return(temp_mp3.path)
      allow(MetadataExtractor).to receive(:call).and_return({duration: 200.0, bitrate: 192})

      described_class.perform_now(track.id, url, user_id: user.id)
      track.reload

      expect(track.audio_file).to be_attached
      expect(track.download_status).to eq("completed")
      expect(track.duration).to eq(200.0)
      expect(track.bitrate).to eq(192)
      expect(track.file_format).to eq("mp3")
    end

    it "skips if audio file is already attached" do
      track.audio_file.attach(io: StringIO.new("existing"), filename: "existing.mp3", content_type: "audio/mpeg")

      expect(MediaDownloadService).not_to receive(:download_audio)
      described_class.perform_now(track.id, url, user_id: user.id)
    end

    it "sets status to downloading during execution" do
      statuses = []
      allow(MediaDownloadService).to receive(:download_audio) do
        statuses << track.reload.download_status
        temp_mp3.path
      end
      allow(MetadataExtractor).to receive(:call).and_return({})

      described_class.perform_now(track.id, url, user_id: user.id)
      expect(statuses).to include("downloading")
    end

    it "sets failed status on transient download error" do
      allow(MediaDownloadService).to receive(:download_audio)
        .and_raise(MediaDownloadService::Error, "yt-dlp failed: something went wrong")

      described_class.perform_now(track.id, url, user_id: user.id)
      track.reload

      expect(track.download_status).to eq("failed")
      expect(track.download_error).to include("something went wrong")
      expect(Track.exists?(track.id)).to be true
    end

    context "permanent YouTube errors" do
      [
        "ERROR: [youtube] abc123: Video unavailable. This video is not available",
        "ERROR: [youtube] abc123: Private video. Sign in if you've been granted access",
        "ERROR: [youtube] abc123: Video unavailable. This video contains content from WMG, who has blocked it on copyright grounds",
        "ERROR: [youtube] abc123: The uploader has not made this video available in your country",
        "ERROR: [youtube] abc123: Video unavailable. This video has been removed by the uploader",
        "ERROR: [youtube] abc123: This video is only available to Music Premium members",
        "ERROR: [youtube] abc123: This live stream recording is not available.",
        "ERROR: [youtube] abc123: Video unavailable. The uploader has not made this video available.",
        "ERROR: [youtube] abc123: Video unavailable. This video contains content from WMG and SME, one or more of whom have blocked it"
      ].each do |error_message|
        it "auto-deletes the track for: #{error_message.truncate(80)}" do
          allow(MediaDownloadService).to receive(:download_audio)
            .and_raise(MediaDownloadService::Error, error_message)

          described_class.perform_now(track.id, url, user_id: user.id)

          expect(Track.exists?(track.id)).to be false
        end
      end

      it "logs the deletion" do
        allow(MediaDownloadService).to receive(:download_audio)
          .and_raise(MediaDownloadService::Error, "ERROR: Video unavailable. This video is not available")
        allow(Rails.logger).to receive(:info).and_call_original
        allow(Rails.logger).to receive(:error).and_call_original

        described_class.perform_now(track.id, url, user_id: user.id)

        expect(Rails.logger).to have_received(:info).with(/\[YouTubeCleanup\] Deleted track ##{track.id}/)
      end

      it "deletes the album if it becomes empty" do
        allow(MediaDownloadService).to receive(:download_audio)
          .and_raise(MediaDownloadService::Error, "ERROR: Video unavailable. This video is not available")

        album = track.album
        described_class.perform_now(track.id, url, user_id: user.id)

        expect(Album.exists?(album.id)).to be false
      end

      it "keeps the album if it still has other tracks" do
        allow(MediaDownloadService).to receive(:download_audio)
          .and_raise(MediaDownloadService::Error, "ERROR: Video unavailable. This video is not available")

        album = track.album
        create(:track, album: album, artist: track.artist, user: track.user)

        described_class.perform_now(track.id, url, user_id: user.id)

        expect(Album.exists?(album.id)).to be true
      end

      it "deletes the artist if they have no remaining tracks" do
        allow(MediaDownloadService).to receive(:download_audio)
          .and_raise(MediaDownloadService::Error, "ERROR: Video unavailable. This video is not available")

        artist = track.artist
        described_class.perform_now(track.id, url, user_id: user.id)

        expect(Artist.exists?(artist.id)).to be false
      end

      it "keeps the artist if they still have other tracks" do
        allow(MediaDownloadService).to receive(:download_audio)
          .and_raise(MediaDownloadService::Error, "ERROR: Video unavailable. This video is not available")

        artist = track.artist
        other_album = create(:album, artist: artist, user: track.user)
        create(:track, album: other_album, artist: artist, user: track.user)

        described_class.perform_now(track.id, url, user_id: user.id)

        expect(Artist.exists?(artist.id)).to be true
      end
    end

    it "retries on rate limit error and keeps downloading status" do
      allow(MediaDownloadService).to receive(:download_audio)
        .and_raise(MediaDownloadService::RateLimitError, "yt-dlp rate limited: HTTP Error 429")

      expect {
        described_class.perform_now(track.id, url, user_id: user.id)
      }.to have_enqueued_job(described_class).with(track.id, url, user_id: user.id)

      track.reload
      expect(track.download_status).to eq("downloading")
      expect(track.download_error).to eq("Rate limited, retrying...")
    end

    it "marks track as failed when rate limit retries are exhausted" do
      allow(MediaDownloadService).to receive(:download_audio)
        .and_raise(MediaDownloadService::RateLimitError, "yt-dlp rate limited: HTTP Error 429")

      # retry_on tracks per-exception counts via exception_executions, not
      # the global executions counter. Setting to 4 means the handler
      # increments to 5, matching attempts: 5 and triggering the exhaustion block.
      job = described_class.new(track.id, url, user_id: user.id)
      job.exception_executions = {"[MediaDownloadService::RateLimitError]" => 4}
      job.perform_now

      track.reload
      expect(track.download_status).to eq("failed")
      expect(track.download_error).to include("Rate limit retries exhausted")
    end

    it "cleans up temp directory" do
      allow(MediaDownloadService).to receive(:download_audio).and_return(temp_mp3.path)
      allow(MetadataExtractor).to receive(:call).and_return({})

      described_class.perform_now(track.id, url, user_id: user.id)

      temp_dirs = Dir.glob(Rails.root.join("tmp/media_downloads/track_#{track.id}_*"))
      expect(temp_dirs).to be_empty
    end

    it "cleans up temp directory even on failure" do
      allow(MediaDownloadService).to receive(:download_audio)
        .and_raise(MediaDownloadService::Error, "fail")

      described_class.perform_now(track.id, url, user_id: user.id)

      temp_dirs = Dir.glob(Rails.root.join("tmp/media_downloads/track_#{track.id}_*"))
      expect(temp_dirs).to be_empty
    end

    context "post-download metadata enrichment for YouTube tracks" do
      it "updates artist from embedded metadata" do
        allow(MediaDownloadService).to receive(:download_audio).and_return(temp_mp3.path)
        allow(MetadataExtractor).to receive(:call).and_return({artist: "Real Artist", duration: 200.0})

        described_class.perform_now(track.id, url, user_id: user.id)
        track.reload

        expect(track.artist.name).to eq("Real Artist")
      end

      it "updates title from embedded metadata" do
        allow(MediaDownloadService).to receive(:download_audio).and_return(temp_mp3.path)
        allow(MetadataExtractor).to receive(:call).and_return({title: "Real Song Title", duration: 200.0})

        described_class.perform_now(track.id, url, user_id: user.id)
        track.reload

        expect(track.title).to eq("Real Song Title")
      end

      it "updates album from embedded metadata when current album is YouTube Singles" do
        track.album.update!(title: YoutubeVideoImportService::SINGLES_ALBUM_TITLE)
        allow(MediaDownloadService).to receive(:download_audio).and_return(temp_mp3.path)
        allow(MetadataExtractor).to receive(:call).and_return({album: "Discovery", duration: 200.0})

        described_class.perform_now(track.id, url, user_id: user.id)
        track.reload

        expect(track.album.title).to eq("Discovery")
      end

      it "does not overwrite album when it is not YouTube Singles" do
        track.album.update!(title: "Custom Playlist Album")
        allow(MediaDownloadService).to receive(:download_audio).and_return(temp_mp3.path)
        allow(MetadataExtractor).to receive(:call).and_return({album: "Different Album", duration: 200.0})

        described_class.perform_now(track.id, url, user_id: user.id)
        track.reload

        expect(track.album.title).to eq("Custom Playlist Album")
      end

      it "does not enrich non-YouTube tracks" do
        non_yt_track = create(:track)
        allow(MediaDownloadService).to receive(:download_audio).and_return(temp_mp3.path)
        allow(MetadataExtractor).to receive(:call).and_return({artist: "Other Artist", title: "Other Title", duration: 200.0})

        described_class.perform_now(non_yt_track.id, "https://example.com/audio.mp3", user_id: user.id)
        non_yt_track.reload

        expect(non_yt_track.artist.name).not_to eq("Other Artist")
      end
    end

    it "broadcasts status updates" do
      allow(MediaDownloadService).to receive(:download_audio).and_return(temp_mp3.path)
      allow(MetadataExtractor).to receive(:call).and_return({})

      expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).at_least(:twice)

      described_class.perform_now(track.id, url, user_id: user.id)
    end
  end
end
