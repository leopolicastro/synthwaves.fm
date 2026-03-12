module Streamable
  extend ActiveSupport::Concern

  def needs_proxy?
    stream_url.present? && !stream_url.start_with?("https://")
  end
end
