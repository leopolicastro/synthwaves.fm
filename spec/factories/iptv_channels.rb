FactoryBot.define do
  factory :iptv_category do
    sequence(:name) { |n| "Category #{n}" }
    sequence(:slug) { |n| "category-#{n}" }
  end

  factory :iptv_channel do
    sequence(:name) { |n| "Channel #{n}" }
    sequence(:tvg_id) { |n| "channel#{n}.us" }
    stream_url { "https://stream.example.com/live.m3u8" }
    active { true }

    trait :with_category do
      iptv_category
    end

    trait :inactive do
      active { false }
    end
  end
end
