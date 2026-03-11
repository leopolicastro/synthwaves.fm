FactoryBot.define do
  factory :download do
    user
    association :downloadable, factory: :album
    status { "pending" }
    total_tracks { 0 }
    processed_tracks { 0 }

    trait :for_track do
      association :downloadable, factory: :track
    end

    trait :for_playlist do
      downloadable { association :playlist, user: user }
    end

    trait :for_library do
      downloadable { nil }
      after(:build) do |download|
        download.downloadable_type = "Library"
      end
    end

    trait :processing do
      status { "processing" }
      total_tracks { 10 }
      processed_tracks { 5 }
    end

    trait :ready do
      status { "ready" }
      total_tracks { 10 }
      processed_tracks { 10 }
    end

    trait :failed do
      status { "failed" }
      error_message { "Something went wrong" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end
