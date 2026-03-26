class ExternalStream < ApplicationRecord
  include Streamable

  belongs_to :user

  validates :name, presence: true
  validates :source_type, presence: true, inclusion: {in: %w[youtube stream]}

  validates :youtube_url, presence: true, if: :youtube?
  validate :youtube_url_must_contain_video_id, if: :youtube?

  validates :stream_url, presence: true, if: :stream?

  before_validation :extract_video_id, if: -> { youtube? && youtube_url.present? && youtube_video_id.blank? }

  def youtube?
    source_type == "youtube"
  end

  def stream?
    source_type == "stream"
  end

  def needs_proxy?
    stream? && super
  end

  private

  def extract_video_id
    self.youtube_video_id = YoutubeUrlParser.extract_video_id(youtube_url)
  end

  def youtube_url_must_contain_video_id
    return if youtube_url.blank?
    return if youtube_video_id.present?

    if YoutubeUrlParser.playlist_url?(youtube_url)
      errors.add(:youtube_url, "is a playlist URL. Use 'Import from YouTube' to import playlists. This form is for individual video or live stream URLs.")
    else
      errors.add(:youtube_url, "doesn't appear to be a valid YouTube video or live stream URL")
    end
  end
end
