class ButtonComponent < ViewComponent::Base
  LAYOUTS = {
    button: {
      base: "inline-flex items-center justify-center font-medium transition-all cursor-pointer",
      include_size: true,
      include_rounded: true
    },
    menu: {
      base: "transition-all cursor-pointer",
      include_size: true,
      include_rounded: false
    },
    inline: {
      base: "transition-colors",
      include_size: false,
      include_rounded: false
    }
  }.freeze

  STYLE_LAYOUT = {
    primary: :button,
    secondary: :button,
    danger: :button,
    ghost: :button,
    link: :button,
    gradient: :button,
    menu_item: :menu,
    inline_link: :inline,
    nav_link: :inline
  }.freeze

  STYLE_CLASSES = {
    primary: "bg-neon-pink text-white hover:shadow-neon-pink",
    secondary: "bg-gray-700 text-neon-cyan hover:bg-gray-600",
    danger: "bg-gray-700 text-red-400 hover:bg-gray-600",
    ghost: "border border-gray-600 text-gray-400 hover:border-neon-cyan hover:text-neon-cyan",
    link: "text-neon-cyan hover:underline",
    gradient: "bg-sunset-gradient text-white hover:shadow-neon-pink",
    menu_item: "block w-full text-left text-white hover:bg-gray-700 hover:text-neon-cyan",
    inline_link: "hover:text-neon-cyan hover:underline",
    nav_link: "text-white hover:text-neon-cyan"
  }.freeze

  SIZE_CLASSES = {
    default: "px-4 py-2 text-sm",
    small: "px-3 py-1.5 text-sm",
    extra_small: "px-2 py-1 text-xs"
  }.freeze

  ROUNDED_CLASSES = {
    lg: "rounded-lg",
    full: "rounded-full"
  }.freeze

  DISABLED_CLASSES = "opacity-50 cursor-not-allowed pointer-events-none"

  VALID_BEHAVIORS = %i[action navigation].freeze

  def initialize(label: nil, behavior: :action, style: :primary, size: :default,
    rounded: :lg, link_url: nil, disabled: false, full_width: false,
    extra_classes: nil, new_tab: false, turbo_frame: nil,
    turbo_action: nil, **extra_attributes)
    @label = label
    @behavior = behavior
    @style = style
    @size = size
    @rounded = rounded
    @link_url = link_url
    @disabled = disabled
    @full_width = full_width
    @extra_classes = extra_classes
    @new_tab = new_tab
    @turbo_frame = turbo_frame
    @turbo_action = turbo_action
    @extra_attributes = extra_attributes
  end

  def render?
    STYLE_LAYOUT.key?(style) &&
      VALID_BEHAVIORS.include?(behavior) &&
      (label.present? || content?)
  end

  private

  attr_reader :label, :behavior, :style, :size, :rounded, :link_url, :disabled,
    :full_width, :extra_classes, :new_tab, :turbo_frame,
    :turbo_action, :extra_attributes

  def disabled? = disabled
  def full_width? = full_width
  def new_tab? = new_tab
  def navigation? = behavior == :navigation

  def tag_name
    navigation? ? :a : :button
  end

  def css_classes
    layout = LAYOUTS[STYLE_LAYOUT[style]]
    classes = [layout[:base], STYLE_CLASSES[style]]
    classes << SIZE_CLASSES[size] if layout[:include_size]
    classes << ROUNDED_CLASSES[rounded] if layout[:include_rounded]
    classes << DISABLED_CLASSES if disabled?
    classes << "w-full" if full_width?
    classes << extra_classes if extra_classes.present?
    classes.join(" ")
  end

  def html_attributes
    attrs = {}

    if navigation?
      attrs[:href] = link_url
      if disabled?
        attrs[:"aria-disabled"] = "true"
        attrs[:tabindex] = "-1"
      end
      if new_tab?
        attrs[:target] = "_blank"
        attrs[:rel] = "noopener noreferrer"
      end
    else
      attrs[:type] = "button" unless extra_attributes.key?(:type)
      attrs[:disabled] = "disabled" if disabled?
    end

    turbo_data = {}
    turbo_data[:turbo_frame] = turbo_frame if turbo_frame
    turbo_data[:turbo_action] = turbo_action if turbo_action

    if turbo_data.any?
      caller_data = extra_attributes[:data] || {}
      attrs[:data] = caller_data.merge(turbo_data)
      return attrs.merge(extra_attributes.except(:data))
    end

    attrs.merge(extra_attributes)
  end
end
