FactoryBot.define do
  factory :external_stream do
    user
    sequence(:name) { |n| "Radio Station #{n}" }
    source_type { "youtube" }
    youtube_url { "https://www.youtube.com/watch?v=jfKfPfyJRdk" }
    youtube_video_id { "jfKfPfyJRdk" }

    trait :stream do
      source_type { "stream" }
      youtube_url { nil }
      youtube_video_id { nil }
      stream_url { "https://radio.example.com/stream" }
    end
  end
end
