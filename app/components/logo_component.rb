class LogoComponent < ViewComponent::Base
  def initialize(size: :md, icon: false)
    @size = size
    @icon = icon
  end

  private

  attr_reader :size

  def icon? = @icon

  def size_classes
    case size
    when :sm then "text-sm"
    when :md then "text-lg"
    when :lg then "text-5xl md:text-6xl lg:text-7xl font-bold"
    end
  end

  def icon_size_classes
    case size
    when :sm then "w-4 h-4"
    when :md then "w-5 h-5"
    when :lg then "w-10 h-10"
    end
  end

  def icon_wrapper_classes
    case size
    when :sm then "w-7 h-7 rounded-md"
    when :md then "w-9 h-9 rounded-lg"
    when :lg then "w-16 h-16 rounded-2xl"
    end
  end
end
