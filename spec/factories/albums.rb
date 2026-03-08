FactoryBot.define do
  factory :album do
    sequence(:title) { |n| "Album #{n}" }
    artist
  end
end
