require "rails_helper"

RSpec.describe MetaTagsHelper, type: :helper do
  before do
    allow(helper.request).to receive(:base_url).and_return("https://synthwaves.fm")
    allow(helper.request).to receive(:original_url).and_return("https://synthwaves.fm/artists/1")
  end

  describe "#meta_tags" do
    it "renders default tags when no content_for is set" do
      output = helper.meta_tags

      expect(output).to include('name="description"')
      expect(output).to include("Self-hosted music streaming")
      expect(output).to include('property="og:title" content="synthwaves.fm"')
      expect(output).to match(/property="og:image" content="https:\/\/synthwaves\.fm\/assets\/hero2-[a-f0-9]+\.jpg"/)
      expect(output).to include('property="og:url" content="https://synthwaves.fm/artists/1"')
      expect(output).to include('property="og:type" content="website"')
      expect(output).to include('property="og:site_name" content="synthwaves.fm"')
      expect(output).to include('name="twitter:card" content="summary_large_image"')
    end

    it "uses content_for(:meta_title) for og:title and twitter:title" do
      helper.content_for(:meta_title, "My Artist — synthwaves.fm")
      output = helper.meta_tags

      expect(output).to include('property="og:title" content="My Artist — synthwaves.fm"')
      expect(output).to include('name="twitter:title" content="My Artist — synthwaves.fm"')
    end

    it "falls back to content_for(:title) when meta_title not set" do
      helper.content_for(:title, "Some Page Title")
      output = helper.meta_tags

      expect(output).to include('property="og:title" content="Some Page Title"')
      expect(output).to include('name="twitter:title" content="Some Page Title"')
    end

    it "prefers meta_title over title" do
      helper.content_for(:title, "Page Title")
      helper.content_for(:meta_title, "Meta Title")
      output = helper.meta_tags

      expect(output).to include('property="og:title" content="Meta Title"')
    end

    it "uses content_for(:meta_description) for description tags" do
      helper.content_for(:meta_description, "Custom description here")
      output = helper.meta_tags

      expect(output).to include('name="description" content="Custom description here"')
      expect(output).to include('property="og:description" content="Custom description here"')
      expect(output).to include('name="twitter:description" content="Custom description here"')
    end

    it "uses summary_large_image when a custom meta_image is set" do
      helper.content_for(:meta_image, "https://synthwaves.fm/custom.jpg")
      output = helper.meta_tags

      expect(output).to include('name="twitter:card" content="summary_large_image"')
      expect(output).to include('property="og:image" content="https://synthwaves.fm/custom.jpg"')
      expect(output).to include('name="twitter:image" content="https://synthwaves.fm/custom.jpg"')
    end

    it "uses content_for(:meta_type) for og:type" do
      helper.content_for(:meta_type, "music.album")
      output = helper.meta_tags

      expect(output).to include('property="og:type" content="music.album"')
    end
  end

  describe "#og_image_url_for" do
    it "returns nil when not attached" do
      attachment = instance_double(ActiveStorage::Attached::One, attached?: false)
      expect(helper.og_image_url_for(attachment)).to be_nil
    end

    it "returns a URL for an attached image" do
      variant = double("variant")
      attachment = double("attachment", attached?: true)
      allow(attachment).to receive(:variant).with(resize_to_limit: [1200, 1200]).and_return(variant)
      allow(helper).to receive(:rails_storage_proxy_url).with(variant).and_return("https://synthwaves.fm/storage/image.jpg")

      expect(helper.og_image_url_for(attachment)).to eq("https://synthwaves.fm/storage/image.jpg")
    end
  end
end
