require "rails_helper"

RSpec.describe Button::Component, type: :component do
  include ViewComponent::TestHelpers

  def render_button(**options, &block)
    render_inline(described_class.new(**options), &block)
  end

  describe "render? guard" do
    it "does not render without label or block" do
      html = render_button(style: :primary)
      expect(html.to_html.strip).to be_empty
    end

    it "does not render with an invalid style" do
      html = render_button(label: "Click", style: :invalid)
      expect(html.to_html.strip).to be_empty
    end

    it "does not render with an invalid behavior" do
      html = render_button(label: "Click", behavior: :invalid)
      expect(html.to_html.strip).to be_empty
    end
  end

  describe "behaviors" do
    it "renders a <button> by default" do
      html = render_button(label: "Click")
      expect(html.at_css("button")).to be_present
    end

    it "renders a <button> for :action behavior" do
      html = render_button(label: "Click", behavior: :action)
      button = html.at_css("button")
      expect(button).to be_present
      expect(button["type"]).to eq("button")
    end

    it "renders an <a> for :navigation behavior" do
      html = render_button(label: "Go", behavior: :navigation, link_url: "/home")
      link = html.at_css("a")
      expect(link).to be_present
      expect(link["href"]).to eq("/home")
    end

    it "does not set type attribute on <a> tags" do
      html = render_button(label: "Go", behavior: :navigation, link_url: "/home")
      link = html.at_css("a")
      expect(link["type"]).to be_nil
    end

    it "defaults button type to 'button' not 'submit'" do
      html = render_button(label: "Click")
      expect(html.at_css("button")["type"]).to eq("button")
    end

    it "allows overriding button type via extra_attributes" do
      html = render_button(label: "Submit", type: "submit")
      expect(html.at_css("button")["type"]).to eq("submit")
    end
  end

  describe "style variants" do
    it "applies primary classes by default" do
      html = render_button(label: "Click")
      expect(html.at_css("button")["class"]).to include("bg-neon-pink", "text-white")
    end

    it "applies secondary classes" do
      html = render_button(label: "Click", style: :secondary)
      expect(html.at_css("button")["class"]).to include("bg-gray-700", "text-neon-cyan")
    end

    it "applies danger classes" do
      html = render_button(label: "Click", style: :danger)
      expect(html.at_css("button")["class"]).to include("bg-gray-700", "text-red-400")
    end

    it "applies ghost classes" do
      html = render_button(label: "Click", style: :ghost)
      classes = html.at_css("button")["class"]
      expect(classes).to include("border", "border-gray-600", "text-gray-400")
    end

    it "applies link classes" do
      html = render_button(label: "Click", style: :link)
      expect(html.at_css("button")["class"]).to include("text-neon-cyan", "hover:underline")
    end

    it "applies gradient classes" do
      html = render_button(label: "Click", style: :gradient)
      expect(html.at_css("button")["class"]).to include("bg-sunset-gradient", "text-white")
    end

    it "applies menu_item classes" do
      html = render_button(label: "Click", style: :menu_item)
      classes = html.at_css("button")["class"]
      expect(classes).to include("block", "w-full", "text-left", "text-white")
    end

    it "excludes inline-flex and rounded for menu_item" do
      html = render_button(label: "Click", style: :menu_item)
      classes = html.at_css("button")["class"]
      expect(classes).not_to include("inline-flex", "items-center", "justify-center", "rounded-lg")
    end
  end

  describe "size variants" do
    it "applies default size classes" do
      html = render_button(label: "Click")
      expect(html.at_css("button")["class"]).to include("px-4", "py-2", "text-sm")
    end

    it "applies small size classes" do
      html = render_button(label: "Click", size: :small)
      expect(html.at_css("button")["class"]).to include("px-3", "py-1.5", "text-sm")
    end

    it "applies extra_small size classes" do
      html = render_button(label: "Click", size: :extra_small)
      expect(html.at_css("button")["class"]).to include("px-2", "py-1", "text-xs")
    end
  end

  describe "disabled state" do
    it "adds disabled attribute to buttons" do
      html = render_button(label: "Click", disabled: true)
      button = html.at_css("button")
      expect(button["disabled"]).to eq("disabled")
      expect(button["class"]).to include("opacity-50", "cursor-not-allowed", "pointer-events-none")
    end

    it "adds aria-disabled and tabindex to links" do
      html = render_button(label: "Go", behavior: :navigation, link_url: "/x", disabled: true)
      link = html.at_css("a")
      expect(link["aria-disabled"]).to eq("true")
      expect(link["tabindex"]).to eq("-1")
      expect(link["disabled"]).to be_nil
      expect(link["class"]).to include("opacity-50")
    end
  end

  describe "full width" do
    it "adds w-full when full_width is true" do
      html = render_button(label: "Click", full_width: true)
      expect(html.at_css("button")["class"]).to include("w-full")
    end

    it "does not add w-full by default" do
      html = render_button(label: "Click")
      expect(html.at_css("button")["class"]).not_to include("w-full")
    end
  end

  describe "extra classes" do
    it "appends extra_classes to the class list" do
      html = render_button(label: "Click", extra_classes: "mt-4 custom-class")
      expect(html.at_css("button")["class"]).to include("mt-4", "custom-class")
    end
  end

  describe "turbo attributes" do
    it "sets data-turbo-frame on buttons" do
      html = render_button(label: "Click", turbo_frame: "modal")
      expect(html.at_css("button")["data-turbo-frame"]).to eq("modal")
    end

    it "sets data-turbo-action on buttons" do
      html = render_button(label: "Click", turbo_action: "advance")
      expect(html.at_css("button")["data-turbo-action"]).to eq("advance")
    end

    it "sets turbo attributes on links" do
      html = render_button(label: "Go", behavior: :navigation, link_url: "/x",
        turbo_frame: "content", turbo_action: "replace")
      link = html.at_css("a")
      expect(link["data-turbo-frame"]).to eq("content")
      expect(link["data-turbo-action"]).to eq("replace")
    end

    it "deep merges turbo data with caller data attributes" do
      html = render_button(label: "Click", turbo_frame: "modal",
        data: {controller: "dialog"})
      button = html.at_css("button")
      expect(button["data-turbo-frame"]).to eq("modal")
      expect(button["data-controller"]).to eq("dialog")
    end
  end

  describe "new tab" do
    it "adds target and rel for navigation links" do
      html = render_button(label: "Go", behavior: :navigation, link_url: "/x", new_tab: true)
      link = html.at_css("a")
      expect(link["target"]).to eq("_blank")
      expect(link["rel"]).to eq("noopener noreferrer")
    end

    it "does not add target/rel to buttons" do
      html = render_button(label: "Click", new_tab: true)
      button = html.at_css("button")
      expect(button["target"]).to be_nil
      expect(button["rel"]).to be_nil
    end
  end

  describe "block content" do
    it "renders block content instead of label" do
      html = render_button(label: "Ignored") { "Block Text" }
      expect(html.text).to include("Block Text")
      expect(html.text).not_to include("Ignored")
    end

    it "renders with block content and no label" do
      html = render_button { "Just Block" }
      expect(html.at_css("button")).to be_present
      expect(html.text).to include("Just Block")
    end
  end

  describe "extra HTML attributes" do
    it "passes through id" do
      html = render_button(label: "Click", id: "my-btn")
      expect(html.at_css("button")["id"]).to eq("my-btn")
    end

    it "passes through data-controller" do
      html = render_button(label: "Click", data: {controller: "modal"})
      expect(html.at_css("button")["data-controller"]).to eq("modal")
    end
  end

  describe "rounded variants" do
    it "applies rounded-lg by default" do
      html = render_button(label: "Click")
      expect(html.at_css("button")["class"]).to include("rounded-lg")
    end

    it "applies rounded-full when specified" do
      html = render_button(label: "Click", rounded: :full)
      classes = html.at_css("button")["class"]
      expect(classes).to include("rounded-full")
      expect(classes).not_to include("rounded-lg")
    end
  end

  describe "base classes" do
    it "includes button-layout base classes for standard styles" do
      html = render_button(label: "Click")
      classes = html.at_css("button")["class"]
      expect(classes).to include("inline-flex", "items-center", "justify-center",
        "font-medium", "rounded-lg", "transition-all", "cursor-pointer")
    end
  end

  describe "inline_link style" do
    it "renders with inline-layout base classes" do
      html = render_button(label: "Title", behavior: :navigation, link_url: "/track/1", style: :inline_link)
      classes = html.at_css("a")["class"]
      expect(classes).to include("transition-colors", "hover:text-neon-cyan", "hover:underline")
    end

    it "excludes button-layout classes" do
      html = render_button(label: "Title", behavior: :navigation, link_url: "/track/1", style: :inline_link)
      classes = html.at_css("a")["class"]
      expect(classes).not_to include("inline-flex", "items-center", "justify-center", "font-medium",
        "rounded-lg", "px-4", "py-2")
    end

    it "silently ignores size and rounded params" do
      html = render_button(label: "Title", behavior: :navigation, link_url: "/track/1",
        style: :inline_link, size: :small, rounded: :full)
      classes = html.at_css("a")["class"]
      expect(classes).not_to include("px-3", "py-1.5", "rounded-full")
    end
  end

  describe "nav_link style" do
    it "renders with inline-layout base classes" do
      html = render_button(label: "Listen", behavior: :navigation, link_url: "/music", style: :nav_link)
      classes = html.at_css("a")["class"]
      expect(classes).to include("transition-colors", "text-white", "hover:text-neon-cyan")
    end

    it "excludes button-layout classes" do
      html = render_button(label: "Listen", behavior: :navigation, link_url: "/music", style: :nav_link)
      classes = html.at_css("a")["class"]
      expect(classes).not_to include("inline-flex", "items-center", "justify-center", "font-medium",
        "rounded-lg", "px-4", "py-2")
    end

    it "silently ignores size and rounded params" do
      html = render_button(label: "Listen", behavior: :navigation, link_url: "/music",
        style: :nav_link, size: :small, rounded: :full)
      classes = html.at_css("a")["class"]
      expect(classes).not_to include("px-3", "py-1.5", "rounded-full")
    end
  end
end
