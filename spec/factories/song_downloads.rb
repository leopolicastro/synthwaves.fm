FactoryBot.define do
  factory :song_download do
    sequence(:job_id) { |n| "job-#{n}-#{SecureRandom.uuid}" }
    url { "https://youtube.com/watch?v=test" }
    source_type { "url" }
    status { "queued" }
    user
  end
end
