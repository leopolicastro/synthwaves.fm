FactoryBot.define do
  factory :radio_queue_track do
    radio_station
    track
    sequence(:position) { |n| n }
    played_at { nil }

    trait :played do
      played_at { Time.current }
    end
  end
end
