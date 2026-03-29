FactoryBot.define do
  factory :album do
    sequence(:title) { |n| "Album #{n}" }
    artist
    user { artist.user }

    trait :with_cover_image do
      after(:create) do |album|
        album.cover_image.attach(io: StringIO.new("fake image"), filename: "cover.png", content_type: "image/png")
      end
    end
  end
end
