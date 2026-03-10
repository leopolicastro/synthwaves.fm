FactoryBot.define do
  factory :track do
    sequence(:title) { |n| "Track #{n}" }
    album
    artist { album.artist }
    duration { 180.0 }
    track_number { 1 }
    disc_number { 1 }
    file_format { "mp3" }
    file_size { 5_000_000 }
    bitrate { 320 }

    trait :youtube do
      youtube_video_id { "dQw4w9WgXcQ" }
      file_format { nil }
      file_size { nil }
      bitrate { nil }
    end
  end
end
