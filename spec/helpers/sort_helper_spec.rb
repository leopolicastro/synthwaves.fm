require "rails_helper"

RSpec.describe SortHelper, type: :helper do
  describe "#sort_link" do
    def stub_params(**overrides)
      params = ActionController::Parameters.new(
        { controller: "albums", action: "index" }.merge(overrides)
      ).permit!

      allow(helper).to receive(:params).and_return(params)
      allow(helper).to receive(:request).and_return(double(params: params))
    end

    it "generates a link with sort and direction params" do
      stub_params
      html = helper.sort_link(Album, :title, "Title")
      expect(html).to include("sort=title")
      expect(html).to include("direction=asc")
      expect(html).to include("Title")
    end

    it "adds active class when column matches current sort" do
      stub_params(sort: "title", direction: "asc")
      html = helper.sort_link(Album, :title, "Title")
      expect(html).to include("active")
    end

    it "toggles direction when column is active with asc" do
      stub_params(sort: "title", direction: "asc")
      html = helper.sort_link(Album, :title, "Title")
      expect(html).to include("direction=desc")
    end

    it "toggles direction when column is active with desc" do
      stub_params(sort: "title", direction: "desc")
      html = helper.sort_link(Album, :title, "Title")
      expect(html).to include("direction=asc")
    end

    it "renders ascending icon when active and toggling to desc" do
      stub_params(sort: "title", direction: "asc")
      html = helper.sort_link(Album, :title, "Title")
      expect(html).to include("Sorted descending")
    end

    it "renders descending icon when active and toggling to asc" do
      stub_params(sort: "title", direction: "desc")
      html = helper.sort_link(Album, :title, "Title")
      expect(html).to include("Sorted ascending")
    end

    it "does not render icon for inactive column" do
      stub_params(sort: "year", direction: "asc")
      html = helper.sort_link(Album, :title, "Title")
      expect(html).not_to include("Sorted")
    end
  end
end
