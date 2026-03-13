FactoryBot.define do
  factory :track do
    sequence(:title) { |n| "Track #{n}" }
    album
    artist { album.artist }
    user { album.user }
    duration { 180.0 }
    track_number { 1 }
    disc_number { 1 }
    file_format { "mp3" }
    file_size { 5_000_000 }
    bitrate { 320 }

    after(:build) do |track|
      unless track.youtube_video_id.present? || track.audio_file.attached?
        track.audio_file.attach(
          io: StringIO.new("fake audio data"),
          filename: "track.mp3",
          content_type: "audio/mpeg"
        )
      end
    end

    trait :youtube do
      youtube_video_id { "dQw4w9WgXcQ" }
      file_format { nil }
      file_size { nil }
      bitrate { nil }
    end

    trait :with_lyrics do
      lyrics { "Verse 1\nSome lyrics here\n\nChorus\nThe chorus goes here" }
    end
  end
end
