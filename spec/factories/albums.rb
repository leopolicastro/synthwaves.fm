FactoryBot.define do
  factory :album do
    sequence(:title) { |n| "Album #{n}" }
    artist
    user { artist.user }
  end
end
