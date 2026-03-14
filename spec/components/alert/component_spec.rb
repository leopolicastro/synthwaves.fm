require "rails_helper"

RSpec.describe Alert::Component, type: :component do
  include ViewComponent::TestHelpers

  it "renders notice variant with correct classes" do
    html = render_inline(described_class.new(text: "Success!", variant: :notice))
    alert = html.at_css("[role='alert']")
    expect(alert["class"]).to include("text-neon-cyan", "bg-neon-cyan/10")
  end

  it "renders alert variant with correct classes" do
    html = render_inline(described_class.new(text: "Error!", variant: :alert))
    alert = html.at_css("[role='alert']")
    expect(alert["class"]).to include("text-red-400", "bg-red-500/10")
  end

  it "renders success variant with correct classes" do
    html = render_inline(described_class.new(text: "Done!", variant: :success))
    alert = html.at_css("[role='alert']")
    expect(alert["class"]).to include("text-laser-green", "bg-laser-green/10")
  end

  it "renders warning variant with correct classes" do
    html = render_inline(described_class.new(text: "Careful!", variant: :warning))
    alert = html.at_css("[role='alert']")
    expect(alert["class"]).to include("text-sunset-orange", "bg-sunset-orange/10")
  end

  it "renders info variant with correct classes" do
    html = render_inline(described_class.new(text: "FYI", variant: :info))
    alert = html.at_css("[role='alert']")
    expect(alert["class"]).to include("text-neon-purple", "bg-neon-purple/10")
  end

  it "renders the text" do
    html = render_inline(described_class.new(text: "Hello world"))
    expect(html.text).to include("Hello world")
  end

  it "renders a dismiss button by default" do
    html = render_inline(described_class.new(text: "Dismiss me"))
    expect(html.at_css("[data-action='alert#dismiss']")).to be_present
  end

  it "hides dismiss button when dismissible is false" do
    html = render_inline(described_class.new(text: "Sticky", dismissible: false))
    expect(html.at_css("[data-action='alert#dismiss']")).to be_nil
  end

  it "sets auto-dismiss data attribute" do
    html = render_inline(described_class.new(text: "Bye!", auto_dismiss: true))
    alert = html.at_css("[role='alert']")
    expect(alert["data-alert-auto-dismiss-value"]).to eq("true")
  end

  it "renders an icon by default" do
    html = render_inline(described_class.new(text: "With icon"))
    expect(html.at_css("svg.w-5")).to be_present
  end

  it "hides the icon when icon is false" do
    html = render_inline(described_class.new(text: "No icon", icon: false))
    expect(html.at_css("svg.w-5")).to be_nil
  end

  it "does not render when text is blank" do
    html = render_inline(described_class.new(text: ""))
    expect(html.to_html.strip).to eq("")
  end

  it "does not render when text is nil" do
    html = render_inline(described_class.new(text: nil))
    expect(html.to_html.strip).to eq("")
  end

  it "has the alert Stimulus controller" do
    html = render_inline(described_class.new(text: "Test"))
    alert = html.at_css("[role='alert']")
    expect(alert["data-controller"]).to eq("alert")
  end
end
