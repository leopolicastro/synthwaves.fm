require "rails_helper"

RSpec.describe Dropdown::Component, type: :component do
  include ViewComponent::TestHelpers

  it "renders the trigger slot" do
    html = render_inline(described_class.new) do |dropdown|
      dropdown.with_trigger { "Menu" }
      "Items"
    end
    button = html.at_css("[data-action='dropdown#toggle']")
    expect(button.text).to include("Menu")
  end

  it "renders menu content" do
    html = render_inline(described_class.new) do |dropdown|
      dropdown.with_trigger { "Open" }
      "<a href='/profile'>Profile</a>".html_safe
    end
    menu = html.at_css("[data-dropdown-target='menu']")
    expect(menu.at_css("a")["href"]).to eq("/profile")
  end

  it "positions menu to the right by default" do
    html = render_inline(described_class.new) do |dropdown|
      dropdown.with_trigger { "Open" }
      "Content"
    end
    menu = html.at_css("[data-dropdown-target='menu']")
    expect(menu["class"]).to include("right-0")
  end

  it "positions menu to the left when specified" do
    html = render_inline(described_class.new(position: :left)) do |dropdown|
      dropdown.with_trigger { "Open" }
      "Content"
    end
    menu = html.at_css("[data-dropdown-target='menu']")
    expect(menu["class"]).to include("left-0")
  end

  it "applies custom width" do
    html = render_inline(described_class.new(width: "w-64")) do |dropdown|
      dropdown.with_trigger { "Open" }
      "Content"
    end
    menu = html.at_css("[data-dropdown-target='menu']")
    expect(menu["class"]).to include("w-64")
  end

  it "has the dropdown Stimulus controller" do
    html = render_inline(described_class.new) do |dropdown|
      dropdown.with_trigger { "Open" }
      "Content"
    end
    expect(html.at_css("[data-controller='dropdown']")).to be_present
  end

  it "starts with menu hidden" do
    html = render_inline(described_class.new) do |dropdown|
      dropdown.with_trigger { "Open" }
      "Content"
    end
    menu = html.at_css("[data-dropdown-target='menu']")
    expect(menu["class"]).to include("hidden")
  end
end
