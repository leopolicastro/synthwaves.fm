require "rails_helper"

RSpec.describe Track, type: :model do
  describe "associations" do
    it { should belong_to(:album) }
    it { should belong_to(:artist) }
    it { should have_one_attached(:audio_file) }
    it { should have_many(:playlist_tracks).dependent(:destroy) }
    it { should have_many(:playlists).through(:playlist_tracks) }
    it { should have_many(:play_histories).dependent(:destroy) }
    it { should have_many(:favorites).dependent(:destroy) }
  end

  describe "validations" do
    it { should validate_presence_of(:title) }
  end

  describe ".search" do
    it "returns tracks matching by title" do
      matching = create(:track, title: "Bohemian Rhapsody")
      non_matching = create(:track, title: "Stairway to Heaven")

      results = Track.search("Bohemian")

      expect(results).to include(matching)
      expect(results).not_to include(non_matching)
    end

    it "returns tracks matching by artist name" do
      artist = create(:artist, name: "Led Zeppelin")
      matching = create(:track, artist: artist, title: "Kashmir")
      non_matching = create(:track, title: "Yesterday")

      results = Track.search("Zeppelin")

      expect(results).to include(matching)
      expect(results).not_to include(non_matching)
    end

    it "returns tracks matching by album title" do
      album = create(:album, title: "Abbey Road")
      matching = create(:track, album: album, title: "Come Together")
      non_matching = create(:track, title: "Yesterday")

      results = Track.search("Abbey")

      expect(results).to include(matching)
      expect(results).not_to include(non_matching)
    end

    it "returns all tracks when query is nil" do
      tracks = create_list(:track, 3)
      expect(Track.search(nil)).to match_array(tracks)
    end

    it "returns all tracks when query is blank" do
      tracks = create_list(:track, 3)
      expect(Track.search("")).to match_array(tracks)
    end
  end

  describe "category scopes" do
    let!(:music_track) { create(:track, artist: create(:artist, category: "music")) }
    let!(:podcast_track) { create(:track, artist: create(:artist, :podcast)) }

    it ".music returns only tracks belonging to music artists" do
      expect(Track.music).to include(music_track)
      expect(Track.music).not_to include(podcast_track)
    end

    it ".podcast returns only tracks belonging to podcast artists" do
      expect(Track.podcast).to include(podcast_track)
      expect(Track.podcast).not_to include(music_track)
    end
  end

  describe ".streamable" do
    it "includes tracks without youtube_video_id" do
      track = create(:track)
      expect(Track.streamable).to include(track)
    end

    it "excludes tracks with youtube_video_id" do
      youtube_track = create(:track, :youtube)
      expect(Track.streamable).not_to include(youtube_track)
    end

    it "chains with .music" do
      music_track = create(:track, artist: create(:artist, category: "music"))
      youtube_music = create(:track, :youtube, artist: create(:artist, category: "music"))
      podcast_track = create(:track, artist: create(:artist, :podcast))

      result = Track.music.streamable
      expect(result).to include(music_track)
      expect(result).not_to include(youtube_music)
      expect(result).not_to include(podcast_track)
    end

    it "chains with .podcast" do
      podcast_artist = create(:artist, :podcast)
      podcast_album = create(:album, artist: podcast_artist)
      podcast_track = create(:track, album: podcast_album, artist: podcast_artist)
      youtube_podcast = create(:track, :youtube, album: podcast_album, artist: podcast_artist)

      result = Track.podcast.streamable
      expect(result).to include(podcast_track)
      expect(result).not_to include(youtube_podcast)
    end
  end

  describe "callbacks" do
    it "enqueues AudioConversionJob for webm files" do
      track = build(:track, file_format: "webm")
      track.audio_file.attach(
        io: StringIO.new("fake audio"),
        filename: "test.webm",
        content_type: "audio/webm"
      )

      expect { track.save! }.to have_enqueued_job(AudioConversionJob).with(track.id)
    end

    it "does not enqueue AudioConversionJob for mp3 files" do
      track = build(:track, file_format: "mp3")
      track.audio_file.attach(
        io: StringIO.new("fake audio"),
        filename: "test.mp3",
        content_type: "audio/mpeg"
      )

      expect { track.save! }.not_to have_enqueued_job(AudioConversionJob)
    end
  end
end
