FactoryBot.define do
  factory :playlist do
    sequence(:name) { |n| "Playlist #{n}" }
    user
  end
end
