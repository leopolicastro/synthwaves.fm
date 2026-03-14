module Dropdown
  class Component < ViewComponent::Base
    POSITION_CLASSES = {
      left: "left-0",
      right: "right-0"
    }.freeze

    renders_one :trigger

    def initialize(position: :right, width: "w-48")
      @position = position.to_sym
      @width = width
    end

    private

    attr_reader :position, :width

    def position_class
      POSITION_CLASSES.fetch(position, POSITION_CLASSES[:right])
    end

    def menu_classes
      "absolute #{position_class} mt-2 #{width} bg-gray-800 rounded-md shadow-lg border border-gray-700 py-1 z-50 hidden"
    end
  end
end
