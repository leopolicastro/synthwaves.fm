require "rails_helper"

RSpec.describe "Queue assignments" do
  {
    AudioConversionJob => "conversion",
    VideoConversionJob => "conversion",
    StreamRecordingJob => "conversion",

    MediaDownloadJob => "imports",
    VideoDownloadJob => "imports",
    YoutubeImportJob => "imports",

    ChatResponseJob => "default",
    CoverArtAttachJob => "default",
    CoverArtSearchJob => "default",
    MetadataExtractionJob => "default",
    EPGCleanupJob => "default",
    EPGSyncJob => "default",
    IPTVChannelSyncJob => "default",
    StationControlJob => "default",
    StationListenerSyncJob => "default",
    AppleMusicEnrichmentJob => "default",
    DatabaseBackupJob => "default",
    DownloadZipJob => "default"
  }.each do |job_class, expected_queue|
    it "#{job_class} is assigned to the #{expected_queue} queue" do
      expect(job_class.new.queue_name).to eq(expected_queue)
    end
  end
end
