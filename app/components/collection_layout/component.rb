module CollectionLayout
  class Component < ViewComponent::Base
    renders_one :actions
    renders_one :header_content
    renders_one :filters
    renders_one :before_grid
    renders_one :empty_state

    def initialize(
      collection:,
      page_key:,
      pagy: nil,
      form_url: nil,
      turbo_frame: nil,
      tab: nil,
      placeholder: "Search...",
      sort_options: nil,
      sort: nil,
      direction: nil,
      query: nil,
      container_classes: "grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6 gap-4 collection-grid",
      empty_label: "items",
      view_toggle: true,
      search: true,
      content_frame: nil
    )
      @collection = collection
      @pagy = pagy
      @page_key = page_key
      @form_url = form_url
      @turbo_frame = turbo_frame
      @tab = tab
      @placeholder = placeholder
      @sort_options = sort_options
      @sort = sort
      @direction = direction
      @query = query
      @container_classes = container_classes
      @empty_label = empty_label
      @view_toggle = view_toggle
      @search = search
      @content_frame = content_frame
    end

    private

    attr_reader :collection, :pagy, :page_key, :form_url, :turbo_frame, :tab,
      :placeholder, :sort_options, :sort, :direction, :query,
      :container_classes, :empty_label, :content_frame

    def view_toggle? = @view_toggle
    def search? = @search
    def has_sort? = sort_options.present?
    def has_tab? = tab.present?
    def has_pagination? = pagy.present?
    def has_content_frame? = content_frame.present?
    def show_controls_row? = filters? || has_sort? || view_toggle?

    def show_actions_bar?
      !search? && (actions? || view_toggle?)
    end

    def outer_data
      data = {}
      if view_toggle?
        data[:controller] = "view-toggle"
        data[:view_toggle_page_key_value] = page_key
      end
      data
    end

    def grid_data
      view_toggle? ? {view_toggle_target: "container"} : {}
    end

    def default_empty_message
      msg = "No #{empty_label} found"
      msg += " for \"#{query}\"" if query.present?
      "#{msg}."
    end
  end
end
