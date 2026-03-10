module RemoteAPI
  module_function

  def authenticate(remote_url, client_id, secret_key)
    uri = URI.parse("#{remote_url}/api/v1/auth/token")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 15
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(client_id: client_id, secret_key: secret_key)

    response = http.request(request)
    json = JSON.parse(response.body)

    unless response.code.to_i == 200 && json["token"]
      abort "Authentication failed: #{json["error"] || response.body}"
    end

    puts "Authenticated successfully"
    json["token"]
  end

  def create_blob(remote_url, token, filename, byte_size, checksum, content_type = "application/octet-stream")
    uri = URI.parse("#{remote_url}/api/import/direct_uploads")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 15
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{token}"
    request.body = JSON.generate(
      filename: filename,
      byte_size: byte_size,
      checksum: checksum,
      content_type: content_type
    )

    response = http.request(request)

    unless response.code.to_i == 201
      raise "Blob creation failed (#{response.code}): #{response.body}"
    end

    JSON.parse(response.body)
  end

  def upload_to_s3(url, headers, file_path)
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 30
    http.read_timeout = 600

    request = Net::HTTP::Put.new(uri.request_uri)
    headers&.each { |key, value| request[key] = value }

    File.open(file_path, "rb") do |file|
      request.body_stream = file
      request["Content-Length"] = File.size(file_path).to_s
      response = http.request(request)

      unless response.code.to_i.between?(200, 299)
        raise "S3 upload failed (#{response.code}): #{response.body}"
      end
    end
  end
end
