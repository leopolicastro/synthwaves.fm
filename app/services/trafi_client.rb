class TrafiClient
  class Error < StandardError; end

  def self.download_url(url, user:)
    download(url, source_type: "url", endpoint: "/download/url", param_key: "url", user: user)
  end

  def self.download_search(query, user:)
    download(query, source_type: "search", endpoint: "/download/search", param_key: "query", user: user)
  end

  def self.download(value, source_type:, endpoint:, param_key:, user:)
    song_download = SongDownload.create!(
      job_id: SecureRandom.uuid,
      url: value,
      source_type: source_type,
      user: user
    )

    webhook_url = Rails.application.routes.url_helpers.webhooks_song_download_url(
      token: song_download.webhook_token,
      host: base_url_host
    )

    response = HTTP.headers(
      "Authorization" => "Bearer #{api_key}"
    ).post(
      "#{base_url}#{endpoint}",
      json: {
        param_key => value,
        "webhook_url" => webhook_url,
        "job_id" => song_download.job_id
      }
    )

    unless response.status.success?
      song_download.update!(status: "failed")
      raise Error, "Trafi returned #{response.status}: #{response.body}"
    end

    total = JSON.parse(response.body.to_s)["total_tracks"]
    song_download.update!(total_tracks: total) if total

    song_download
  end

  def self.base_url
    Rails.application.credentials.dig(:trafi, :base_url) || "http://192.168.1.67:8000"
  end

  def self.api_key
    Rails.application.credentials.dig(:trafi, :api_key)
  end

  def self.base_url_host
    Rails.application.credentials.dig(:trafi, :webhook_host) || "localhost:3000"
  end

  private_class_method :download, :base_url, :api_key, :base_url_host
end
