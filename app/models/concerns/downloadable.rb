module Downloadable
  extend ActiveSupport::Concern

  def downloading? = download_status == "downloading"
  def download_failed? = download_status == "failed"
  def download_completed? = download_status == "completed"
end
