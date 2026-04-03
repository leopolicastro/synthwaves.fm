require "rails_helper"

RSpec.describe Maintenance::CoverArtBulkSearchTask do
  let(:task) { described_class.new }

  describe "#collection" do
    it "includes albums without cover images" do
      album = create(:album)
      expect(task.collection).to include(album)
    end

    it "excludes albums that already have cover images" do
      album = create(:album, :with_cover_image)
      expect(task.collection).not_to include(album)
    end
  end

  describe "#count" do
    it "returns the number of albums to process" do
      create_list(:album, 3)
      create(:album, :with_cover_image)

      expect(task.count).to eq(3)
    end
  end

  describe "#process" do
    it "enqueues CoverArtSearchJob for the album" do
      album = create(:album)

      expect {
        task.process(album)
      }.to have_enqueued_job(CoverArtSearchJob).with(album)
    end

    it "staggers jobs with incremental 3-second delays" do
      albums = create_list(:album, 3)

      freeze_time do
        albums.each { |a| task.process(a) }

        expect { task.process(create(:album)) }
          .to have_enqueued_job(CoverArtSearchJob).at(9.seconds.from_now)
      end
    end
  end
end
