module API
  module V1
    class FavoriteSerializer < Blueprinter::Base
      identifier :id

      fields :favorable_type, :favorable_id, :created_at

      field :favorable do |favorite|
        case favorite.favorable
        when Track
          {id: favorite.favorable.id, title: favorite.favorable.title, artist: {name: favorite.favorable.artist.name}}
        when Album
          {id: favorite.favorable.id, title: favorite.favorable.title, artist: {name: favorite.favorable.artist.name}}
        when Artist
          {id: favorite.favorable.id, name: favorite.favorable.name}
        end
      end
    end
  end
end
