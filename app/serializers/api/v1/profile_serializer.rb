module API
  module V1
    class ProfileSerializer < Blueprinter::Base
      identifier :id

      fields :name, :email_address, :theme, :created_at

      field :stats do |user|
        {
          artists_count: user.artists.count,
          albums_count: user.albums.count,
          tracks_count: user.tracks.count,
          playlists_count: user.playlists.count
        }
      end
    end
  end
end
