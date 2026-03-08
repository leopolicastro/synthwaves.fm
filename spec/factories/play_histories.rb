FactoryBot.define do
  factory :play_history do
    user
    track
    played_at { Time.current }
  end
end
