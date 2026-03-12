require "rails_helper"

RSpec.describe CoverArtAttachJob, type: :job do
  let(:album) { create(:album) }
  let(:image_data) { Base64.strict_encode64("fake image data") }

  it "attaches cover art to the album" do
    described_class.perform_now(album, image_data, "image/jpeg")

    expect(album.cover_image).to be_attached
    expect(album.cover_image.content_type).to eq("image/jpeg")
  end

  it "skips if cover image is already attached" do
    album.cover_image.attach(
      io: StringIO.new("existing"),
      filename: "existing.jpg",
      content_type: "image/jpeg"
    )

    expect {
      described_class.perform_now(album, image_data, "image/png")
    }.not_to change { album.cover_image.blob.id }
  end

  it "defaults to image/jpeg when mime_type is nil" do
    described_class.perform_now(album, image_data, nil)

    expect(album.cover_image).to be_attached
    expect(album.cover_image.content_type).to eq("image/jpeg")
  end
end
