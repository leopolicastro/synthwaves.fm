module BottomTabBar
  class Component < ViewComponent::Base
    Tab = Data.define(:label, :path, :icon)

    def initialize(current_path:, user:)
      @current_path = current_path
      @user = user
    end

    def tabs
      @tabs ||= [
        Tab.new(label: "Library", path: helpers.library_path, icon: :library),
        Tab.new(label: "Listen", path: helpers.music_path, icon: :listen),
        Tab.new(label: "Watch", path: helpers.tv_path, icon: :watch),
        Tab.new(label: "Search", path: helpers.search_path, icon: :search)
      ].compact
    end

    def active?(tab)
      case tab.icon
      when :library
        @current_path.start_with?("/library", "/playlists", "/favorites")
      when :listen
        @current_path.start_with?("/music", "/artists", "/albums", "/tracks")
      when :watch
        @current_path.start_with?("/tv")
      when :search
        @current_path.start_with?("/search")
      else
        false
      end
    end

    def tab_classes(tab)
      if active?(tab)
        "text-neon-cyan"
      else
        "text-white"
      end
    end

    def icon_svg(tab)
      helpers.icon(tab.icon)
    end
  end
end
