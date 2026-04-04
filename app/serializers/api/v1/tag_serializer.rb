module API
  module V1
    class TagSerializer < Blueprinter::Base
      identifier :id

      fields :name, :tag_type
    end
  end
end
