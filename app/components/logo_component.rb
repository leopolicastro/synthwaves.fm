class LogoComponent < ViewComponent::Base
  def initialize(size: :md, icon: false, text: true)
    @size = size
    @icon = icon
    @text = text
  end

  private

  attr_reader :size

  def icon? = @icon
  def text? = @text

  def size_classes
    case size
    when :sm then "text-sm"
    when :md then "text-lg"
    when :lg then "text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-bold"
    end
  end

  def icon_wrapper_classes
    case size
    when :sm then "w-7 h-7 rounded-md border border-neon-purple/30"
    when :md then "w-9 h-9 rounded-lg border border-neon-purple/30"
    when :lg then "w-16 h-16 rounded-2xl border border-neon-purple/30"
    end
  end
end
