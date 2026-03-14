module Badge
  class Component < ViewComponent::Base
    VARIANT_CLASSES = {
      default: "bg-gray-700 text-gray-300",
      primary: "bg-neon-pink/20 text-neon-pink",
      accent: "bg-neon-cyan/20 text-neon-cyan",
      success: "bg-laser-green/20 text-laser-green",
      warning: "bg-sunset-orange/20 text-sunset-orange",
      danger: "bg-red-500/20 text-red-400",
      genre: "bg-neon-cyan/20 text-neon-cyan",
      mood: "bg-neon-purple/20 text-neon-purple"
    }.freeze

    SIZE_CLASSES = {
      small: "px-1.5 py-0.5 text-xs",
      medium: "px-2 py-0.5 text-xs",
      large: "px-3 py-1 text-sm"
    }.freeze

    def initialize(text:, variant: :default, size: :medium, dismissible: false)
      @text = text
      @variant = variant.to_sym
      @size = size.to_sym
      @dismissible = dismissible
    end

    def render?
      text.present?
    end

    private

    attr_reader :text, :variant, :size, :dismissible

    def dismissible? = dismissible

    def variant_classes
      VARIANT_CLASSES.fetch(variant, VARIANT_CLASSES[:default])
    end

    def size_classes
      SIZE_CLASSES.fetch(size, SIZE_CLASSES[:medium])
    end

    def css_classes
      "inline-flex items-center gap-1 rounded-full font-medium #{variant_classes} #{size_classes}"
    end
  end
end
