require "rails_helper"

RSpec.describe PIPComponent, type: :component do
  include ViewComponent::TestHelpers

  def render_component
    render_inline(described_class.new)
  end

  it "renders a turbo-permanent container" do
    html = render_component
    container = html.at_css("#pip-player")
    expect(container).to be_present
    expect(container["data-turbo-permanent"]).not_to be_nil
  end

  it "starts hidden" do
    html = render_component
    expect(html.at_css("#pip-player")["class"]).to include("hidden")
  end

  it "has the pip controller" do
    html = render_component
    expect(html.at_css("#pip-player")["data-controller"]).to eq("pip")
  end

  it "renders a close button" do
    html = render_component
    close_btn = html.at_css("[data-action='pip#close']")
    expect(close_btn).to be_present
  end

  it "renders a video slot" do
    html = render_component
    slot = html.at_css("[data-pip-target='slot']")
    expect(slot).to be_present
  end

  it "renders a title target" do
    html = render_component
    title = html.at_css("[data-pip-target='title']")
    expect(title).to be_present
  end

  it "renders an open button" do
    html = render_component
    open_btn = html.at_css("[data-action='pip#open']")
    expect(open_btn).to be_present
  end
end
