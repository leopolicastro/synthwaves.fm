FactoryBot.define do
  factory :video_playback_position do
    user
    video
    position { 0.0 }
  end
end
