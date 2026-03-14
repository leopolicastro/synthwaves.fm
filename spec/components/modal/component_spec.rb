require "rails_helper"

RSpec.describe Modal::Component, type: :component do
  include ViewComponent::TestHelpers

  it "renders a dialog element" do
    html = render_inline(described_class.new) { "Body" }
    expect(html.at_css("dialog")).to be_present
  end

  it "renders a title when provided" do
    html = render_inline(described_class.new(title: "Confirm")) { "Body" }
    expect(html.at_css("h3").text).to eq("Confirm")
  end

  it "renders content in the body" do
    html = render_inline(described_class.new) { "Modal body content" }
    expect(html.text).to include("Modal body content")
  end

  it "renders a close button when cancellable" do
    html = render_inline(described_class.new(cancellable: true)) { "Body" }
    expect(html.at_css("[data-action='modal#close']")).to be_present
  end

  it "hides close button when not cancellable" do
    html = render_inline(described_class.new(cancellable: false)) { "Body" }
    expect(html.at_css("[data-action='modal#close']")).to be_nil
  end

  it "has the modal Stimulus controller" do
    html = render_inline(described_class.new) { "Body" }
    expect(html.at_css("[data-controller='modal']")).to be_present
  end

  it "sets open value" do
    html = render_inline(described_class.new(open: true)) { "Body" }
    expect(html.at_css("[data-controller='modal']")["data-modal-open-value"]).to eq("true")
  end

  it "enables backdrop click by default" do
    html = render_inline(described_class.new) { "Body" }
    dialog = html.at_css("dialog")
    expect(dialog["data-action"]).to include("modal#backdropClick")
  end

  it "disables backdrop click when backdrop_cancellable is false" do
    html = render_inline(described_class.new(backdrop_cancellable: false)) { "Body" }
    dialog = html.at_css("dialog")
    expect(dialog["data-action"]).to be_nil
  end

  it "renders the header slot" do
    html = render_inline(described_class.new) do |modal|
      modal.with_header { "<h2>Custom Header</h2>".html_safe }
      "Body"
    end
    expect(html.at_css("h2").text).to eq("Custom Header")
  end

  it "renders the footer slot" do
    html = render_inline(described_class.new) do |modal|
      modal.with_footer { "<button class='save-btn'>Save</button>".html_safe }
      "Body"
    end
    expect(html.at_css(".save-btn").text).to eq("Save")
  end

  it "renders the opener slot" do
    html = render_inline(described_class.new) do |modal|
      modal.with_opener { "<button>Open Modal</button>".html_safe }
      "Body"
    end
    opener = html.at_css("[data-action='click->modal#show']")
    expect(opener).to be_present
    expect(opener.at_css("button").text).to eq("Open Modal")
  end

  it "applies theme-appropriate classes to dialog" do
    html = render_inline(described_class.new) { "Body" }
    dialog = html.at_css("dialog")
    expect(dialog["class"]).to include("bg-gray-800", "text-white", "border-gray-700")
  end
end
