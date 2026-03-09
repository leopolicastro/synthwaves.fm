FactoryBot.define do
  factory :recording do
    iptv_channel
    title { "Test Recording" }
    starts_at { Time.current }
    ends_at { 1.hour.from_now }
    status { "scheduled" }

    trait :with_programme do
      epg_programme do
        association :epg_programme, channel_id: iptv_channel.tvg_id
      end
    end

    trait :recording_now do
      status { "recording" }
      starts_at { 10.minutes.ago }
    end

    trait :processing do
      status { "processing" }
      starts_at { 1.hour.ago }
      ends_at { 10.minutes.ago }
    end

    trait :ready do
      status { "ready" }
      starts_at { 2.hours.ago }
      ends_at { 1.hour.ago }
      duration { 3600.0 }
      file_size { 500_000_000 }
    end

    trait :failed do
      status { "failed" }
      starts_at { 2.hours.ago }
      ends_at { 1.hour.ago }
      error_message { "ffmpeg recording failed" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end

  factory :user_recording do
    user
    recording
  end
end
