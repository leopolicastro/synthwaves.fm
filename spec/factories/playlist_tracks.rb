FactoryBot.define do
  factory :playlist_track do
    playlist
    track
    sequence(:position) { |n| n }
  end
end
