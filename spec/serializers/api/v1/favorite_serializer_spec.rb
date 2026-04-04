require "rails_helper"

RSpec.describe API::V1::FavoriteSerializer do
  it "serializes a track favorite" do
    track = create(:track)
    favorite = create(:favorite, favorable: track, user: track.user)
    result = described_class.render_as_hash(favorite)

    expect(result).to include(:id, :favorable_type, :favorable_id, :favorable, :created_at)
    expect(result[:favorable]).to include(:id, :title)
  end

  it "serializes an artist favorite" do
    artist = create(:artist)
    favorite = create(:favorite, favorable: artist, user: artist.user)
    result = described_class.render_as_hash(favorite)

    expect(result[:favorable]).to include(:id, :name)
  end
end
