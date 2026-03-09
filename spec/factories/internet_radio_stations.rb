FactoryBot.define do
  factory :internet_radio_category do
    sequence(:name) { |n| "Genre #{n}" }
    sequence(:slug) { |n| "genre-#{n}" }
  end

  factory :internet_radio_station do
    sequence(:name) { |n| "Station #{n}" }
    sequence(:uuid) { |n| "station-uuid-#{n}" }
    stream_url { "https://stream.example.com/radio.mp3" }
    codec { "MP3" }
    bitrate { 128 }
    active { true }

    trait :with_category do
      internet_radio_category
    end

    trait :inactive do
      active { false }
    end

    trait :http_stream do
      stream_url { "http://stream.example.com/radio.mp3" }
    end
  end
end
