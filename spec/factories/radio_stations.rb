FactoryBot.define do
  factory :radio_station do
    playlist
    user { playlist.user }
    status { "stopped" }
    playback_mode { "shuffle" }
    bitrate { 192 }
    crossfade { true }
    crossfade_duration { 3.0 }
    sequence(:mount_point) { |n| "/station-#{n}.mp3" }
  end
end
