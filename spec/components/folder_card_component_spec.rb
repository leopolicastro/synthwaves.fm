require "rails_helper"

RSpec.describe FolderCardComponent, type: :component do
  include ViewComponent::TestHelpers

  let(:user) { create(:user) }
  let(:folder) { create(:folder, user: user, name: "My Show") }

  def render_component(folder:)
    render_inline(described_class.new(folder: folder))
  end

  it "renders the folder name" do
    html = render_component(folder: folder)
    expect(html.text).to include("My Show")
  end

  it "renders video count" do
    create(:video, user: user, folder: folder)
    create(:video, user: user, folder: folder)

    html = render_component(folder: folder)
    expect(html.text).to include("2 videos")
  end

  it "renders singular video count" do
    create(:video, user: user, folder: folder)

    html = render_component(folder: folder)
    expect(html.text).to include("1 video")
  end

  it "renders season count" do
    create(:video, user: user, folder: folder, season_number: 1)
    create(:video, user: user, folder: folder, season_number: 2)

    html = render_component(folder: folder)
    expect(html.text).to include("2 seasons")
  end

  it "links to folder show page" do
    html = render_component(folder: folder)
    link = html.at_css("a")
    expect(link["href"]).to eq("/folders/#{folder.id}")
  end

  it "shows folder icon when no thumbnails" do
    html = render_component(folder: folder)
    expect(html.at_css("svg")).to be_present
  end

  it "includes collection-card class for view toggle support" do
    html = render_component(folder: folder)
    expect(html.at_css(".collection-card")).to be_present
  end
end
