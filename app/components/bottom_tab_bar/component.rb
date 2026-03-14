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
      case tab.icon
      when :library
        '<svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/></svg>'
      when :listen
        '<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20"><path d="M18 3a1 1 0 00-1.196-.98l-10 2A1 1 0 006 5v9.114A4.369 4.369 0 005 14c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V7.82l8-1.6v5.894A4.37 4.37 0 0015 12c-1.657 0-3 .895-3 2s1.343 2 3 2 3-.895 3-2V3z"/></svg>'
      when :watch
        '<svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'
      when :search
        '<svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>'
      end
    end
  end
end
