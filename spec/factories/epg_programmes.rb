FactoryBot.define do
  factory :epg_programme do
    sequence(:channel_id) { |n| "channel#{n}.us" }
    title { "Test Programme" }
    starts_at { 30.minutes.ago }
    ends_at { 30.minutes.from_now }

    trait :current do
      starts_at { 30.minutes.ago }
      ends_at { 30.minutes.from_now }
    end

    trait :upcoming do
      starts_at { 1.hour.from_now }
      ends_at { 2.hours.from_now }
    end

    trait :expired do
      starts_at { 3.hours.ago }
      ends_at { 1.hour.ago }
    end

    trait :with_details do
      subtitle { "Episode 5" }
      description { "A fascinating programme about testing factories." }
    end
  end
end
