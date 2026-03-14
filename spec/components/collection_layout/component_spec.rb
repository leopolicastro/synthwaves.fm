require "rails_helper"

RSpec.describe CollectionLayout::Component, type: :component do
  include ViewComponent::TestHelpers
  include Rails.application.routes.url_helpers

  let(:items) { %w[item1 item2] }
  let(:no_items) { [] }
  let(:pagy) { instance_double(Pagy, series_nav: '<nav class="pagy">Pages</nav>') }
  let(:sort_options) { {"name" => "Name", "created_at" => "Date Added"} }

  let(:default_params) do
    {
      collection: items,
      page_key: "test-page",
      form_url: "/test",
      turbo_frame: "test-content"
    }
  end

  def render_component(**overrides, &block)
    params = default_params.merge(overrides)
    block ||= proc { "test content" }
    render_inline(described_class.new(**params), &block)
  end

  describe "view-toggle wiring" do
    it "adds view-toggle controller and page-key by default" do
      html = render_component
      outer = html.at_css("[data-controller='view-toggle']")
      expect(outer).to be_present
      expect(outer["data-view-toggle-page-key-value"]).to eq("test-page")
    end

    it "sets container target on grid" do
      html = render_component
      expect(html.at_css("[data-view-toggle-target='container']")).to be_present
    end

    it "omits controller and targets when view_toggle: false" do
      html = render_component(view_toggle: false)
      expect(html.at_css("[data-controller='view-toggle']")).to be_nil
      expect(html.at_css("[data-view-toggle-target='container']")).to be_nil
    end
  end

  describe "search form" do
    it "renders form targeting the turbo_frame" do
      html = render_component
      form = html.at_css("form")
      expect(form["data-turbo-frame"]).to eq("test-content")
      expect(form["action"]).to eq("/test")
    end

    it "wires search controller" do
      html = render_component
      expect(html.at_css("[data-controller='search']")).to be_present
      expect(html.at_css("[data-search-target='form']")).to be_present
      expect(html.at_css("[data-search-target='input']")).to be_present
    end

    it "renders hidden tab field when set" do
      html = render_component(tab: "albums")
      hidden = html.at_css("input[type='hidden'][name='tab']")
      expect(hidden["value"]).to eq("albums")
    end

    it "omits hidden tab field when nil" do
      html = render_component
      expect(html.at_css("input[type='hidden'][name='tab']")).to be_nil
    end

    it "sets placeholder and query on search input" do
      html = render_component(placeholder: "Search albums...", query: "jazz")
      input = html.at_css("input[name='q']")
      expect(input["placeholder"]).to eq("Search albums...")
      expect(input["value"]).to eq("jazz")
    end

    it "omits entire search section when search: false" do
      html = render_component(search: false)
      expect(html.at_css("[data-controller='search']")).to be_nil
      expect(html.at_css("form")).to be_nil
    end
  end

  describe "sort controls" do
    it "renders sort and direction dropdowns" do
      html = render_component(sort_options: sort_options, sort: "created_at", direction: "desc")
      sort_select = html.at_css("select[name='sort']")
      expect(sort_select).to be_present
      expect(sort_select.css("option").map { |o| [o["value"], o.text] }).to eq([["name", "Name"], ["created_at", "Date Added"]])
      expect(sort_select.at_css("option[selected]")["value"]).to eq("created_at")

      dir_select = html.at_css("select[name='direction']")
      expect(dir_select.at_css("option[selected]")["value"]).to eq("desc")
    end

    it "auto-submits on sort change" do
      html = render_component(sort_options: sort_options)
      expect(html.at_css("select[name='sort']")["data-action"]).to eq("change->search#submit")
      expect(html.at_css("select[name='direction']")["data-action"]).to eq("change->search#submit")
    end

    it "omits sort controls when sort_options is nil" do
      html = render_component
      expect(html.at_css("select[name='sort']")).to be_nil
      expect(html.at_css("select[name='direction']")).to be_nil
    end
  end

  describe "view toggle button" do
    it "renders inside search controls when search is true" do
      html = render_component(search: true, view_toggle: true)
      search_div = html.at_css("[data-controller='search']")
      expect(search_div.at_css("[data-view-toggle-target='gridBtn']")).to be_present
    end

    it "renders in actions row when search is false" do
      html = render_component(search: false, view_toggle: true) do |c|
        c.with_actions { "<span>Action</span>".html_safe }
        "content"
      end
      row = html.at_css(".flex.justify-between")
      expect(row.at_css("[data-view-toggle-target='gridBtn']")).to be_present
    end

    it "is omitted when view_toggle: false" do
      html = render_component(view_toggle: false)
      expect(html.at_css("[data-view-toggle-target='gridBtn']")).to be_nil
    end
  end

  describe "filters slot" do
    it "renders before sort controls in the controls row" do
      html = render_component(sort_options: sort_options) do |c|
        c.with_filters { '<span class="custom-filter">Filter</span>'.html_safe }
        "content"
      end
      controls_html = html.at_css(".flex.flex-wrap.items-center.gap-2").inner_html
      expect(controls_html.index("custom-filter")).to be < controls_html.index('name="sort"')
    end
  end

  describe "actions slot" do
    it "renders in its own row when search is present" do
      html = render_component(search: true) do |c|
        c.with_actions { '<a class="test-action">New</a>'.html_safe }
        "content"
      end
      expect(html.at_css(".flex.justify-end.mb-4 .test-action")).to be_present
    end

    it "shares row with view toggle when no search" do
      html = render_component(search: false) do |c|
        c.with_actions { '<a class="test-action">Add</a>'.html_safe }
        "content"
      end
      row = html.at_css(".flex.justify-between")
      expect(row.at_css(".test-action")).to be_present
      expect(row.at_css("[data-view-toggle-target='gridBtn']")).to be_present
    end
  end

  describe "header_content slot" do
    it "renders above all other sections" do
      html = render_component do |c|
        c.with_header_content { '<div class="import-forms">Import</div>'.html_safe }
        "content"
      end
      outer_html = html.at_css("[data-controller='view-toggle']").inner_html
      expect(outer_html.index("import-forms")).to be < outer_html.index("data-controller=\"search\"")
    end
  end

  describe "before_grid slot" do
    it "renders between search and grid" do
      html = render_component do |c|
        c.with_before_grid { '<div class="folders">Folders</div>'.html_safe }
        "content"
      end
      outer_html = html.at_css("[data-controller='view-toggle']").inner_html
      expect(outer_html.index("folders")).to be > outer_html.index("data-controller=\"search\"")
      expect(outer_html.index("folders")).to be < outer_html.index("collection-grid")
    end
  end

  describe "container" do
    it "uses default grid classes" do
      html = render_component
      expect(html.at_css(".collection-grid")).to be_present
    end

    it "applies custom container classes" do
      html = render_component(container_classes: "space-y-3 custom-container")
      expect(html.at_css(".custom-container")).to be_present
    end
  end

  describe "pagination" do
    it "renders when pagy is present" do
      html = render_component(pagy: pagy)
      expect(html.at_css(".pagy")).to be_present
    end

    it "omits when pagy is nil" do
      html = render_component(pagy: nil)
      expect(html.at_css(".pagy")).to be_nil
    end
  end

  describe "empty state" do
    it "shows default message with empty_label" do
      html = render_component(collection: no_items, empty_label: "albums")
      expect(html.text).to include("No albums found")
    end

    it "interpolates query into default message" do
      html = render_component(collection: no_items, empty_label: "albums", query: "jazz")
      expect(html.text).to include('No albums found for "jazz"')
    end

    it "uses custom empty_state slot instead of default" do
      html = render_component(collection: no_items) do |c|
        c.with_empty_state { '<div class="custom-empty">Nothing here</div>'.html_safe }
      end
      expect(html.at_css(".custom-empty")).to be_present
      expect(html.text).not_to include("No items found")
    end
  end

  describe "content frame" do
    it "wraps in turbo-frame when content_frame is set" do
      html = render_component(content_frame: "albums-list")
      frame = html.at_css("turbo-frame#albums-list")
      expect(frame).to be_present
      expect(frame["data-turbo-action"]).to eq("replace")
    end

    it "renders without turbo-frame when content_frame is nil" do
      html = render_component(content_frame: nil)
      expect(html.at_css("turbo-frame")).to be_nil
    end
  end

  describe "content block" do
    it "renders block content inside the container" do
      html = render_component { "Card content here" }
      container = html.at_css(".collection-grid")
      expect(container.text).to include("Card content here")
    end

    it "does not render content when collection is empty" do
      html = render_component(collection: no_items) { "Should not appear" }
      expect(html.text).not_to include("Should not appear")
    end
  end
end
