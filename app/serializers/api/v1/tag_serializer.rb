module API
  module V1
    class TagSerializer
      def self.to_full(tag)
        {
          id: tag.id,
          name: tag.name,
          tag_type: tag.tag_type
        }
      end
    end
  end
end
