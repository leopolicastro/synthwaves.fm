module Modal
  class Component < ViewComponent::Base
    renders_one :header
    renders_one :footer
    renders_one :opener

    def initialize(title: nil, open: false, cancellable: true, backdrop_cancellable: true)
      @title = title
      @open = open
      @cancellable = cancellable
      @backdrop_cancellable = backdrop_cancellable
    end

    private

    attr_reader :title, :open, :cancellable, :backdrop_cancellable

    def open? = open
    def cancellable? = cancellable
    def backdrop_cancellable? = backdrop_cancellable
  end
end
