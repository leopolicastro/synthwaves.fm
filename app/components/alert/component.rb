module Alert
  class Component < ViewComponent::Base
    VARIANT_CLASSES = {
      notice: "text-neon-cyan bg-neon-cyan/10 border-neon-cyan/20",
      alert: "text-red-400 bg-red-500/10 border-red-500/20",
      success: "text-laser-green bg-laser-green/10 border-laser-green/20",
      warning: "text-sunset-orange bg-sunset-orange/10 border-sunset-orange/20",
      info: "text-neon-purple bg-neon-purple/10 border-neon-purple/20"
    }.freeze

    DISMISS_CLASSES = {
      notice: "text-neon-cyan/60 hover:text-neon-cyan",
      alert: "text-red-400/60 hover:text-red-400",
      success: "text-laser-green/60 hover:text-laser-green",
      warning: "text-sunset-orange/60 hover:text-sunset-orange",
      info: "text-neon-purple/60 hover:text-neon-purple"
    }.freeze

    ICONS = {
      notice: '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>',
      alert: '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>',
      success: '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>',
      warning: '<path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>',
      info: '<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>'
    }.freeze

    def initialize(text:, variant: :notice, dismissible: true, auto_dismiss: false, icon: true)
      @text = text
      @variant = variant.to_sym
      @dismissible = dismissible
      @auto_dismiss = auto_dismiss
      @icon = icon
    end

    def render?
      text.present?
    end

    private

    attr_reader :text, :variant, :dismissible, :auto_dismiss, :icon

    def variant_classes
      VARIANT_CLASSES.fetch(variant, VARIANT_CLASSES[:notice])
    end

    def dismiss_classes
      DISMISS_CLASSES.fetch(variant, DISMISS_CLASSES[:notice])
    end

    def icon_path
      ICONS.fetch(variant, ICONS[:notice])
    end

    def dismissible? = dismissible
    def auto_dismiss? = auto_dismiss
    def show_icon? = icon
  end
end
