FactoryBot.define do
  factory :video do
    user
    sequence(:title) { |n| "Video #{n}" }
    duration { 120.0 }
    width { 1920 }
    height { 1080 }
    file_format { "mp4" }
    file_size { 50_000_000 }
    video_codec { "h264" }
    audio_codec { "aac" }
    bitrate { 5000 }
    status { "ready" }

    trait :processing do
      status { "processing" }
    end

    trait :failed do
      status { "failed" }
      error_message { "Conversion failed" }
    end

    trait :in_folder do
      folder
      season_number { 1 }
      episode_number { 1 }
    end
  end
end
