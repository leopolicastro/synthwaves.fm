require "rails_helper"

RSpec.describe StorageHelper, type: :helper do
  describe "#storage_preconnect_tag" do
    context "with disk storage" do
      it "returns nil" do
        allow(ActiveStorage::Blob).to receive(:service)
          .and_return(ActiveStorage::Service::DiskService.new(root: "/tmp"))

        expect(helper.storage_preconnect_tag).to be_nil
      end
    end

    context "with S3-compatible storage" do
      it "returns a preconnect link tag for the storage endpoint" do
        endpoint = "https://us-east-1.linodeobjects.com"
        client_config = double(endpoint: URI.parse(endpoint))
        client = double(config: client_config)
        bucket = double(client: client)
        service = double(bucket: bucket)

        allow(ActiveStorage::Blob).to receive(:service).and_return(service)

        result = helper.storage_preconnect_tag
        expect(result).to include('rel="preconnect"')
        expect(result).to include("href=\"#{endpoint}\"")
      end
    end

    context "with mirror storage wrapping S3" do
      it "unwraps the primary and returns a preconnect link tag" do
        endpoint = "https://us-east-1.linodeobjects.com"
        client_config = double(endpoint: URI.parse(endpoint))
        client = double(config: client_config)
        bucket = double(client: client)
        primary_service = double(bucket: bucket)
        mirror_service = double(primary: primary_service)

        allow(ActiveStorage::Blob).to receive(:service).and_return(mirror_service)

        result = helper.storage_preconnect_tag
        expect(result).to include('rel="preconnect"')
        expect(result).to include("href=\"#{endpoint}\"")
      end
    end
  end
end
