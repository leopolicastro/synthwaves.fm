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

    it "matches by prefix" do
      matching = create(:track, title: "Bohemian Rhapsody")
      create(:track, title: "Stairway to Heaven")

      expect(Track.search("Boh")).to include(matching)
    end

    it "finds a track immediately after creation" do
      track = create(:track, title: "Instant Index Test")

      expect(Track.search("Instant")).to include(track)
    end

    it "does not find a track after it is destroyed" do
      track = create(:track, title: "Ephemeral Song")
      expect(Track.search("Ephemeral")).to include(track)

      track.destroy!
      expect(Track.search("Ephemeral")).to be_empty
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
    it "includes tracks with an audio file attached" do
      track = create(:track)
      track.audio_file.attach(io: StringIO.new("audio"), filename: "test.mp3", content_type: "audio/mpeg")
      expect(Track.streamable).to include(track)
    end

    it "excludes tracks without an audio file" do
      track = create(:track, :youtube)
      expect(Track.streamable).not_to include(track)
    end

    it "excludes YouTube tracks without audio files" do
      youtube_track = create(:track, :youtube)
      expect(Track.streamable).not_to include(youtube_track)
    end

    it "includes YouTube tracks that have downloaded audio files" do
      youtube_track = create(:track, :youtube)
      youtube_track.audio_file.attach(io: StringIO.new("audio"), filename: "test.mp3", content_type: "audio/mpeg")
      expect(Track.streamable).to include(youtube_track)
    end
  end

  describe "download status methods" do
    it "#downloading? returns true when status is downloading" do
      track = build(:track, download_status: "downloading")
      expect(track).to be_downloading
    end

    it "#download_failed? returns true when status is failed" do
      track = build(:track, download_status: "failed")
      expect(track).to be_download_failed
    end

    it "#download_completed? returns true when status is completed" do
      track = build(:track, download_status: "completed")
      expect(track).to be_download_completed
    end
  end

  describe "search index update on move" do
    it "reindexes when album_id changes" do
      track = create(:track, title: "Movable Song")
      new_album = create(:album, title: "Destination Album")

      track.update!(album: new_album)

      results = Track.search("Destination")
      expect(results).to include(track)
    end

    it "reindexes when artist_id changes" do
      track = create(:track, title: "Transferable Song")
      new_artist = create(:artist, name: "Receiving Artist")

      track.update!(artist: new_artist)

      results = Track.search("Receiving")
      expect(results).to include(track)
    end
  end

  describe ".by_genre" do
    it "returns tracks with the given genre tag" do
      tag = Tag.create!(name: "electronic", tag_type: "genre")
      track = create(:track)
      Tagging.create!(tag: tag, taggable: track, user: track.user)
      other_track = create(:track)

      results = Track.by_genre("electronic")
      expect(results).to include(track)
      expect(results).not_to include(other_track)
    end

    it "is case-insensitive" do
      tag = Tag.create!(name: "electronic", tag_type: "genre")
      track = create(:track)
      Tagging.create!(tag: tag, taggable: track, user: track.user)

      expect(Track.by_genre("Electronic")).to include(track)
    end
  end

  describe ".by_language" do
    it "returns tracks with the given language" do
      en_track = create(:track, language: "en")
      ja_track = create(:track, language: "ja")

      results = Track.by_language("en")
      expect(results).to include(en_track)
      expect(results).not_to include(ja_track)
    end
  end

  describe ".by_decade" do
    it "returns tracks within the given decade" do
      track_2010s = create(:track, release_year: 2013)
      track_2020s = create(:track, release_year: 2023)

      results = Track.by_decade("2010")
      expect(results).to include(track_2010s)
      expect(results).not_to include(track_2020s)
    end
  end

  describe ".genre_names" do
    it "returns distinct genre tag names for tracks" do
      tag = Tag.create!(name: "electronic", tag_type: "genre")
      track = create(:track)
      Tagging.create!(tag: tag, taggable: track, user: track.user)

      expect(Track.genre_names).to include("electronic")
    end
  end

  describe ".available_languages" do
    it "returns distinct language codes" do
      create(:track, language: "en")
      create(:track, language: "ja")
      create(:track, language: nil)

      result = Track.available_languages
      expect(result).to contain_exactly("en", "ja")
    end
  end

  describe ".available_decades" do
    it "returns distinct decades sorted descending" do
      create(:track, release_year: 2013)
      create(:track, release_year: 2023)
      create(:track, release_year: nil)

      result = Track.available_decades
      expect(result).to eq([2020, 2010])
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
