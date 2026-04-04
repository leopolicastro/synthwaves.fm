module API
  module V1
    class TrackSerializer < Blueprinter::Base
      identifier :id

      view :minimal do
        field :title
        association :artist, blueprint: ArtistSerializer, view: :ref do |track|
          {name: track.artist.name}
        end
      end

      view :embedded do
        field :title
        field :duration
        association :artist, blueprint: ArtistSerializer, view: :ref
        association :album, blueprint: AlbumSerializer, view: :ref
      end

      view :summary do
        fields :title, :track_number, :disc_number, :duration, :file_format
        field :has_audio do |track|
          track.audio_file.attached?
        end
      end

      view :full do
        fields :title, :track_number, :disc_number, :duration,
          :bitrate, :file_format, :file_size, :lyrics, :created_at
        field :has_audio do |track|
          track.audio_file.attached?
        end
        association :artist, blueprint: ArtistSerializer, view: :ref
        association :album, blueprint: AlbumSerializer, view: :ref
      end
    end
  end
end
