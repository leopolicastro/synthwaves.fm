class VideoCardComponent < ViewComponent::Base
  def initialize(video:, show_episode_number: false)
    @video = video
    @show_episode_number = show_episode_number
  end

  private

  attr_reader :video

  def show_episode_number?
    @show_episode_number && video.episode_number.present?
  end

  def episode_label
    "E#{video.episode_number}"
  end

  def formatted_duration
    return nil unless video.duration
    minutes = (video.duration / 60).floor
    seconds = (video.duration % 60).floor
    format("%d:%02d", minutes, seconds)
  end

  def resolution_label
    return nil unless video.height
    case video.height
    when 0..480 then "SD"
    when 481..720 then "720p"
    when 721..1080 then "1080p"
    else "4K"
    end
  end
end
