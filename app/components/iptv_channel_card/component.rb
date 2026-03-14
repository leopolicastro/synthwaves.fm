module IPTVChannelCard
  class Component < ViewComponent::Base
    def initialize(channel:)
      @channel = channel
    end

    private

    attr_reader :channel

    delegate :name, :logo_url, :stream_url, :country, :iptv_category, to: :channel

    INITIALS_COLORS = %w[
      bg-blue-600 bg-purple-600 bg-pink-600 bg-red-600 bg-orange-600
      bg-amber-600 bg-emerald-600 bg-teal-600 bg-cyan-600 bg-indigo-600
    ].freeze

    def initials
      name.scan(/[A-Z0-9]/).first(3).join.presence || name[0..1].upcase
    end

    def initials_color
      INITIALS_COLORS[name.sum % INITIALS_COLORS.size]
    end
  end
end
